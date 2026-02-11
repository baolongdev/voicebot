import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../../capabilities/protocol/protocol.dart';
import '../../../../capabilities/mcp/mcp_server.dart';
import '../../../../capabilities/web_host/local_web_host_service.dart';
import '../../../../capabilities/voice/session_coordinator.dart';
import '../../../../capabilities/voice/transport_client.dart';
import '../../../../capabilities/voice/websocket_transport_client.dart';
import '../../../../capabilities/voice/mqtt_transport_client.dart';
import '../../../../core/config/app_config.dart';
import '../../../form/domain/models/server_form_data.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/entities/chat_response.dart';
import '../../domain/entities/related_chat_image.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/throttle.dart';
import '../services/xiaozhi_text_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required SessionCoordinator sessionCoordinator,
    Uri? Function()? webHostBaseUriResolver,
    Future<Map<String, dynamic>?> Function(Map<String, dynamic> payload)?
    mcpHandleMessage,
  }) : _sessionCoordinator = sessionCoordinator,
       _webHostBaseUriResolver = webHostBaseUriResolver,
       _mcpHandleMessage = mcpHandleMessage ?? McpServer.shared.handleMessage,
       _responsesController = StreamController<ChatResponse>.broadcast(),
       _audioController = StreamController<List<int>>.broadcast(),
       _errorController = StreamController<Failure>.broadcast(),
       _speakingController = StreamController<bool>.broadcast() {
    _textService = XiaozhiTextService(
      sessionCoordinator: _sessionCoordinator,
      sessionIdProvider: () => _transport?.sessionId ?? '',
    );
  }

  final SessionCoordinator _sessionCoordinator;
  final Uri? Function()? _webHostBaseUriResolver;
  final Future<Map<String, dynamic>?> Function(Map<String, dynamic> payload)
  _mcpHandleMessage;
  final StreamController<ChatResponse> _responsesController;
  final StreamController<List<int>> _audioController;
  final StreamController<Failure> _errorController;
  final StreamController<bool> _speakingController;

  StreamSubscription<Map<String, dynamic>>? _jsonSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _speakingSubscription;
  ChatConfig? _lastConfig;
  TransportClient? _transport;
  late final XiaozhiTextService _textService;
  bool _isConnected = false;
  bool _isSpeaking = false;
  int _mcpRequestId = 30000;
  bool _knowledgeVoiceInFlight = false;
  String? _lastKnowledgeVoiceQuery;
  DateTime _lastKnowledgeVoiceAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastLocalVolumeAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _suppressVolumeFailureUntil = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _suppressBlockedTopicUntil = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _blockedSuppressionTimer;
  int? _lastLocalVolumeTarget;
  DateTime _lastBlockedReplyAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastBlockedInput;
  String? _lastImageContextQuery;
  DateTime _lastImageContextAt = DateTime.fromMillisecondsSinceEpoch(0);
  String? _lastKnowledgeDocQuery;
  String? _lastKnowledgeDocName;
  DateTime _lastKnowledgeDocAt = DateTime.fromMillisecondsSinceEpoch(0);
  final List<_RecentText> _recentBotTexts = <_RecentText>[];
  static const Duration _recentTextWindow = Duration(seconds: 10);
  static const Duration _knowledgeVoiceCooldown = Duration(seconds: 6);
  static const Duration _knowledgeDocCacheTtl = Duration(seconds: 6);
  static const Duration _imageContextTtl = Duration(minutes: 10);
  static const String _knowledgeMarker = '__KBCTX__';
  static const String _missingMqttCode = 'missing_mqtt';
  static const bool _forceKnowledgeModeEnabled = true;
  static const Set<String> _knowledgeKeywords = <String>{
    'san pham',
    'thong tin',
    'xuat xu',
    'thanh phan',
    'han su dung',
    'bao quan',
    'huong dan',
    'uu diem',
    'cong dung',
    'gia',
    'quy cach',
    'bot chanh',
    'nuoc cot chanh',
    'muoi ot xanh',
    'tinh dau chanh',
    'tinh dau',
    'syrup chanh',
    'chanh gung mat ong',
    'chanh mat ong',
    'tra mang cau',
    'chavi',
    'cha vi',
    'chai vi',
    'chanh viet',
    'chanhviet',
  };
  static const Set<String> _smallTalkKeywords = <String>{
    'xin chao',
    'hello',
    'hi',
    'cam on',
    'tam biet',
    'hen gap lai',
    'subscribe',
    'la la school',
    'bai hat',
    'am nhac',
    'nhac',
    'video',
  };
  final Throttler _errorLogThrottle = Throttler(25000);

  @override
  Stream<ChatResponse> get responses => _responsesController.stream;

  @override
  Stream<List<int>> get audioStream => _audioController.stream;

  @override
  Stream<double> get incomingLevel => _sessionCoordinator.incomingLevel;

  @override
  Stream<double> get outgoingLevel => _sessionCoordinator.outgoingLevel;

  @override
  Stream<Failure> get errors => _errorController.stream;

  @override
  Stream<bool> get speakingStream => _speakingController.stream;

  @override
  int get serverSampleRate => _sessionCoordinator.serverSampleRate;

  @override
  Future<Result<bool>> connect(ChatConfig config) async {
    if (_isConnected || _transport != null) {
      await disconnect();
    }
    if (config.transportType == TransportType.webSockets) {
      if (config.url.isEmpty || config.accessToken.isEmpty) {
        return Result.failure(
          const Failure(message: 'Thiếu thông tin kết nối'),
        );
      }
    } else if (config.transportType == TransportType.mqtt &&
        config.mqttConfig == null) {
      return Result.failure(
        const Failure(message: 'Chưa có cấu hình MQTT', code: _missingMqttCode),
      );
    }
    _lastConfig = config;
    AppLogger.event(
      'ChatRepository',
      'connect_start',
      fields: <String, Object?>{'transport': config.transportType.name},
    );

    _transport = _buildTransport(config);
    if (_transport == null) {
      return Result.failure(const Failure(message: 'Không thể chọn transport'));
    }

    final opened = await _sessionCoordinator.connect(_transport!);
    if (!opened) {
      AppLogger.event(
        'ChatRepository',
        'connect_failed',
        fields: <String, Object?>{
          'reason': 'open_audio_channel_failed',
          'transport': config.transportType.name,
        },
      );
      await _sessionCoordinator.disconnect();
      _transport = null;
      return Result.failure(
        Failure(
          message: config.transportType == TransportType.mqtt
              ? 'Không thể kết nối MQTT'
              : 'Không thể kết nối WebSocket',
        ),
      );
    }
    AppLogger.event(
      'ChatRepository',
      'connect_success',
      fields: <String, Object?>{'transport': config.transportType.name},
    );
    _isConnected = true;

    _jsonSubscription = _sessionCoordinator.incomingJson.listen(
      _handleIncomingJson,
      onError: (_) {
        _errorController.add(const Failure(message: 'Lỗi nhận dữ liệu'));
      },
    );
    _audioSubscription = _sessionCoordinator.incomingAudio.listen(
      (data) => _audioController.add(data),
      onError: (_) {
        _errorController.add(const Failure(message: 'Lỗi nhận âm thanh'));
      },
    );
    _errorSubscription = _sessionCoordinator.errors.listen((error) {
      if (_errorLogThrottle.shouldRun()) {
        AppLogger.event(
          'ChatRepository',
          'network_error',
          fields: <String, Object?>{'message': error},
          level: 'D',
        );
      }
      _isConnected = false;
      _errorController.add(Failure(message: error));
    });
    _speakingSubscription = _sessionCoordinator.speaking.listen(_setSpeaking);

    return Result.success(true);
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _blockedSuppressionTimer?.cancel();
    _blockedSuppressionTimer = null;
    _sessionCoordinator.setPlaybackSuppressed(false);
    await _jsonSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _speakingSubscription?.cancel();
    _jsonSubscription = null;
    _audioSubscription = null;
    _errorSubscription = null;
    _speakingSubscription = null;
    try {
      await _sessionCoordinator.disconnect().timeout(
        const Duration(seconds: 1),
      );
    } catch (_) {}
    _transport = null;
  }

  @override
  Future<void> startListening({bool enableMic = true}) async {
    await _sessionCoordinator.startListening(enableMic: enableMic);
  }

  @override
  Future<void> stopListening() async {
    await _sessionCoordinator.stopListening();
  }

  @override
  Future<void> setListeningMode(ListeningMode mode) async {
    _sessionCoordinator.setListeningMode(mode);
  }

  @override
  Future<void> setTextSendMode(TextSendMode mode) async {
    return;
  }

  @override
  Future<Result<bool>> sendGreeting(String text) async {
    if (!_isConnected) {
      if (_lastConfig == null) {
        return Result.failure(const Failure(message: 'Chưa cấu hình kết nối'));
      }
      final result = await connect(_lastConfig!);
      if (!result.isSuccess) {
        return result;
      }
    }
    return _textService.sendTextRequest(text);
  }

  @override
  Future<Result<bool>> sendMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty) {
      return Result.failure(const Failure(message: 'Nội dung trống'));
    }
    if (!_isConnected) {
      if (_lastConfig == null) {
        return Result.failure(const Failure(message: 'Chưa cấu hình kết nối'));
      }
      final result = await connect(_lastConfig!);
      if (!result.isSuccess) {
        return result;
      }
    }
    final blocked = await _checkBlockedPhraseAndHandle(input);
    if (blocked) {
      AppLogger.event(
        'ChatRepository',
        'send_message_blocked',
        fields: <String, Object?>{'text': input},
        level: 'D',
      );
      return Result.success(true);
    }
    final textWithKnowledge = _shouldUseKnowledgeContext(input)
        ? await _buildKnowledgeContextPrompt(input)
        : input;
    return _textService.sendTextRequest(textWithKnowledge);
  }

  @override
  Future<void> sendAudio(List<int> data) async {
    await _sessionCoordinator.sendAudio(data);
  }

  @override
  Future<List<RelatedChatImage>> getRelatedImagesForQuery(
    String query, {
    int? topK,
    int? maxImages,
  }) async {
    if (!AppConfig.chatRelatedImagesEnabled) {
      return const <RelatedChatImage>[];
    }
    final inputQuery = query.trim();
    if (inputQuery.isEmpty) {
      return const <RelatedChatImage>[];
    }
    var effectiveQuery = inputQuery;
    final now = DateTime.now();
    if (!_isGenericImageRequest(inputQuery)) {
      _lastImageContextQuery = inputQuery;
      _lastImageContextAt = now;
    }
    if (_isGenericImageRequest(inputQuery) &&
        _lastImageContextQuery != null &&
        now.difference(_lastImageContextAt) <= _imageContextTtl) {
      effectiveQuery = _lastImageContextQuery!;
      AppLogger.event(
        'ChatRepository',
        'related_images_context_fallback',
        fields: <String, Object?>{
          'input_query': inputQuery,
          'effective_query': effectiveQuery,
        },
        level: 'D',
      );
    }

    final topKValue = (topK ?? AppConfig.chatRelatedImagesSearchTopK).clamp(
      1,
      10,
    );
    final maxImageCount = (maxImages ?? AppConfig.chatRelatedImagesMaxCount)
        .clamp(1, 12);

    AppLogger.event(
      'ChatRepository',
      'related_images_request',
      fields: <String, Object?>{
        'query': inputQuery,
        'effective_query': effectiveQuery,
      },
    );

    final docImages = await _fetchKnowledgeDocImages(
      effectiveQuery,
      maxImages: maxImageCount,
    );
    if (docImages.isNotEmpty) {
      AppLogger.event(
        'ChatRepository',
        'related_images_doc_hit',
        fields: <String, Object?>{
          'query': inputQuery,
          'effective_query': effectiveQuery,
          'images': docImages.length,
        },
        level: 'D',
      );
      return docImages;
    }

    final startedAt = DateTime.now();
    try {
      final result = await _callMcpTool(
        name: 'self.knowledge.search_images',
        arguments: <String, dynamic>{
          'query': effectiveQuery,
          'top_k': topKValue,
          'max_images': maxImageCount,
        },
        logRequest: true,
      );
      final payload = _decodeToolPayload(result);
      if (payload is! Map) {
        return const <RelatedChatImage>[];
      }
      final rows = payload['images'];
      if (rows is! List || rows.isEmpty) {
        AppLogger.event(
          'ChatRepository',
          'related_images_no_images',
          fields: <String, Object?>{
            'query': inputQuery,
            'effective_query': effectiveQuery,
          },
          level: 'D',
        );
        return const <RelatedChatImage>[];
      }

      final baseUri = _resolveWebHostBaseUri();
      if (baseUri == null) {
        AppLogger.event(
          'ChatRepository',
          'related_images_no_web_host',
          fields: <String, Object?>{
            'query': inputQuery,
            'effective_query': effectiveQuery,
          },
          level: 'D',
        );
        return const <RelatedChatImage>[];
      }

      final imagesById = <String, RelatedChatImage>{};
      var droppedNonLocal = 0;
      for (final row in rows) {
        if (row is! Map) {
          continue;
        }
        final item = Map<String, dynamic>.from(row);
        final id = (item['id'] ?? '').toString().trim();
        final urlRaw = (item['url'] ?? '').toString().trim();
        if (id.isEmpty || urlRaw.isEmpty) {
          continue;
        }
        final resolvedUrl = _resolveLocalImageUrl(urlRaw, baseUri);
        if (resolvedUrl == null) {
          droppedNonLocal += 1;
          continue;
        }
        final fileName = (item['file_name'] ?? '').toString().trim();
        final docName = (item['doc_name'] ?? '').toString().trim();
        final image = RelatedChatImage(
          id: id,
          documentName: docName.isEmpty ? 'unknown' : docName,
          fileName: fileName.isEmpty ? 'image' : fileName,
          url: resolvedUrl,
          mimeType: (item['mime_type'] ?? '').toString().trim(),
          bytes: (item['bytes'] as num?)?.toInt() ?? 0,
          score: (item['score'] as num?)?.toInt() ?? 0,
          createdAt: DateTime.tryParse(
            (item['created_at'] ?? '').toString().trim(),
          ),
        );
        final existing = imagesById[id];
        if (existing == null || image.score > existing.score) {
          imagesById[id] = image;
        }
      }
      if (droppedNonLocal > 0) {
        AppLogger.event(
          'ChatRepository',
          'related_images_drop_non_local',
          fields: <String, Object?>{
            'query': inputQuery,
            'effective_query': effectiveQuery,
            'dropped': droppedNonLocal,
          },
          level: 'D',
        );
      }

      final merged = imagesById.values.toList(growable: false)
        ..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) {
            return byScore;
          }
          final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      final limited = merged.take(maxImageCount).toList(growable: false);
      if (limited.isNotEmpty) {
        _lastImageContextQuery = effectiveQuery;
        _lastImageContextAt = now;
      }
      AppLogger.event(
        'ChatRepository',
        'related_images_loaded',
        fields: <String, Object?>{
          'query': inputQuery,
          'effective_query': effectiveQuery,
          'images': limited.length,
          'latency_ms': DateTime.now().difference(startedAt).inMilliseconds,
        },
        level: 'D',
      );
      return limited;
    } catch (error) {
      AppLogger.event(
        'ChatRepository',
        'related_images_error',
        fields: <String, Object?>{
          'query': inputQuery,
          'effective_query': effectiveQuery,
          'error': error.toString(),
        },
        level: 'D',
      );
      return const <RelatedChatImage>[];
    }
  }

  Future<List<RelatedChatImage>> _fetchKnowledgeDocImages(
    String query, {
    required int maxImages,
  }) async {
    final normalized = _normalizeForKnowledge(query);
    if (normalized.isEmpty) {
      return const <RelatedChatImage>[];
    }
    final now = DateTime.now();
    String? docName;
    if (_lastKnowledgeDocQuery == normalized &&
        now.difference(_lastKnowledgeDocAt) <= _knowledgeDocCacheTtl) {
      docName = _lastKnowledgeDocName;
    }
    docName ??= await _findKnowledgeDocNameForQuery(query);
    if (docName == null || docName.trim().isEmpty) {
      return const <RelatedChatImage>[];
    }
    _lastKnowledgeDocQuery = normalized;
    _lastKnowledgeDocName = docName;
    _lastKnowledgeDocAt = now;
    return _listImagesForDocument(docName, maxImages: maxImages);
  }

  Future<String?> _findKnowledgeDocNameForQuery(String query) async {
    final response = await _callMcpTool(
      name: 'self.knowledge.search',
      arguments: <String, dynamic>{'query': query, 'top_k': 1},
      logRequest: true,
    );
    final payload = _decodeToolPayload(response);
    if (payload is! Map) {
      return null;
    }
    final rows = payload['results'];
    if (rows is! List || rows.isEmpty) {
      return null;
    }
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final name = (row['name'] ?? '').toString().trim();
      if (name.isNotEmpty) {
        return name;
      }
      final title = (row['title'] ?? '').toString().trim();
      if (title.isNotEmpty) {
        return title;
      }
    }
    return null;
  }

  Future<List<RelatedChatImage>> _listImagesForDocument(
    String docName, {
    required int maxImages,
  }) async {
    final trimmed = docName.trim();
    if (trimmed.isEmpty) {
      return const <RelatedChatImage>[];
    }
    final baseUri = _resolveWebHostBaseUri();
    if (baseUri == null) {
      return const <RelatedChatImage>[];
    }
    final result = await _callMcpTool(
      name: 'self.knowledge.list_images',
      arguments: <String, dynamic>{'doc_name': trimmed, 'limit': maxImages},
      logRequest: true,
    );
    final payload = _decodeToolPayload(result);
    if (payload is! Map) {
      return const <RelatedChatImage>[];
    }
    final rows = payload['images'];
    if (rows is! List || rows.isEmpty) {
      return const <RelatedChatImage>[];
    }
    final imagesById = <String, RelatedChatImage>{};
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final item = Map<String, dynamic>.from(row);
      final id = (item['id'] ?? '').toString().trim();
      final urlRaw = (item['url'] ?? '').toString().trim();
      if (id.isEmpty || urlRaw.isEmpty) {
        continue;
      }
      final resolvedUrl = _resolveLocalImageUrl(urlRaw, baseUri);
      if (resolvedUrl == null) {
        continue;
      }
      final fileName = (item['file_name'] ?? '').toString().trim();
      final doc = (item['doc_name'] ?? '').toString().trim();
      imagesById[id] = RelatedChatImage(
        id: id,
        documentName: doc.isEmpty ? trimmed : doc,
        fileName: fileName.isEmpty ? 'image' : fileName,
        url: resolvedUrl,
        mimeType: (item['mime_type'] ?? '').toString().trim(),
        bytes: (item['bytes'] as num?)?.toInt() ?? 0,
        score: 0,
        createdAt: DateTime.tryParse(
          (item['created_at'] ?? '').toString().trim(),
        ),
      );
      if (imagesById.length >= maxImages) {
        break;
      }
    }
    return imagesById.values.toList(growable: false);
  }

  void _handleIncomingJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final suppressionActive = _isBlockedSuppressionActive();
    if (type == 'tts') {
      final state = json['state'] as String? ?? '';
      if (state == 'sentence_start') {
        final text = json['text'] as String? ?? '';
        if (text.isNotEmpty) {
          if (suppressionActive) {
            AppLogger.event(
              'ChatRepository',
              'suppress_blocked_topic_server_tts',
              fields: <String, Object?>{'text': text, 'state': state},
              level: 'D',
            );
            return;
          }
          if (_shouldSuppressBlockedTopicText(text)) {
            AppLogger.event(
              'ChatRepository',
              'suppress_blocked_topic_server_text',
              fields: <String, Object?>{'text': text},
              level: 'D',
            );
            return;
          }
          if (_shouldSuppressVolumeFailureText(text)) {
            AppLogger.event(
              'ChatRepository',
              'suppress_server_volume_failure_text',
              fields: <String, Object?>{'text': text},
              level: 'D',
            );
            return;
          }
          _rememberBotText(text);
          _responsesController.add(ChatResponse(text: text, isUser: false));
        }
      }
      return;
    }

    if (type == 'llm') {
      if (suppressionActive) {
        AppLogger.event(
          'ChatRepository',
          'suppress_blocked_topic_server_llm',
          level: 'D',
        );
        return;
      }
      final emotion = json['emotion'] as String?;
      if (emotion != null && emotion.isNotEmpty) {
        _responsesController.add(
          ChatResponse(text: '', isUser: false, emotion: emotion),
        );
      }
      return;
    }

    if (type == 'stt') {
      final text = json['text'] as String? ?? '';
      if (text.isNotEmpty) {
        if (text.contains(_knowledgeMarker) ||
            text.contains('[NGU_CANH_TAI_LIEU_NOI_BO]')) {
          return;
        }
        if (_isSpeaking && _isLikelyEcho(text)) {
          return;
        }
        _responsesController.add(ChatResponse(text: text, isUser: true));
        unawaited(_checkBlockedPhraseAndHandle(text));
        unawaited(_tryHandleLocalVolumeCommand(text));
        if (_shouldUseKnowledgeContext(text)) {
          unawaited(_injectKnowledgeForVoice(text));
        }
      }
      return;
    }

    final text = json['text'] as String? ?? '';
    if (text.isNotEmpty) {
      if (suppressionActive) {
        AppLogger.event(
          'ChatRepository',
          'suppress_blocked_topic_server_text',
          fields: <String, Object?>{'text': text},
          level: 'D',
        );
        return;
      }
      _responsesController.add(ChatResponse(text: text, isUser: false));
    }
  }

  void dispose() {
    disconnect();
    _blockedSuppressionTimer?.cancel();
    _blockedSuppressionTimer = null;
    _sessionCoordinator.setPlaybackSuppressed(false);
    _responsesController.close();
    _audioController.close();
    _errorController.close();
    _speakingController.close();
  }

  void _setSpeaking(bool speaking) {
    _isSpeaking = speaking;
    _speakingController.add(speaking);
  }

  TransportClient? _buildTransport(ChatConfig config) {
    switch (config.transportType) {
      case TransportType.mqtt:
        final mqtt = config.mqttConfig;
        if (mqtt == null) {
          return null;
        }
        return MqttTransportClient(mqttConfig: mqtt);
      case TransportType.webSockets:
        return WebsocketTransportClient(
          deviceInfo: config.deviceInfo,
          url: config.url,
          accessToken: config.accessToken,
        );
    }
  }

  void _rememberBotText(String text) {
    _recentBotTexts.add(
      _RecentText(text: _normalize(text), at: DateTime.now()),
    );
    _pruneRecentTexts();
  }

  bool _isLikelyEcho(String text) {
    _pruneRecentTexts();
    final normalized = _normalize(text);
    if (normalized.isEmpty) {
      return false;
    }
    for (final recent in _recentBotTexts) {
      if (recent.text == normalized) {
        return true;
      }
    }
    return false;
  }

  void _pruneRecentTexts() {
    final cutoff = DateTime.now().subtract(_recentTextWindow);
    _recentBotTexts.removeWhere((item) => item.at.isBefore(cutoff));
  }

  String _normalize(String text) {
    final lower = text.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9\u00C0-\u024F]+'), ' ');
    return cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<String> _buildKnowledgeContextPrompt(String input) async {
    final query = input.trim();
    if (query.isEmpty || !_shouldUseKnowledgeContext(query)) {
      return input;
    }

    try {
      final snippets = await _searchKnowledgeSnippets(
        query,
        topK: _forceKnowledgeModeEnabled ? 1 : 3,
        maxSnippetChars: 1400,
        includeFullContent: true,
      );
      final normalizedQuestion = _normalizeQuestionForAgent(query);
      if (snippets.isNotEmpty) {
        AppLogger.event(
          'ChatRepository',
          'knowledge_context_attached',
          fields: <String, Object?>{'matches': snippets.length},
          level: 'D',
        );

        final contextBlock = snippets.join('\n');
        return '''
$input

[NGU_CANH_TAI_LIEU_NOI_BO]
$contextBlock
[/NGU_CANH_TAI_LIEU_NOI_BO]

THONG_TIN_BO_SUNG:
- Cau hoi goc: "$query"
- Cau hoi chuan hoa: "$normalizedQuestion"
- Quy uoc alias: "cha vi", "chai vi", "tra vi", "cha vi", "chá vi" deu la "Chavi".

YEU_CAU_TRA_LOI:
- Neu NGU_CANH_TAI_LIEU_NOI_BO co thong tin lien quan, bat buoc tra loi theo noi dung do.
- KHONG duoc noi "khong tim thay", "khong co thong tin", hoac "co the ban nham ten" khi da co du lieu lien quan.
- Neu du lieu chua du, tra loi phan da co truoc, sau do moi hoi them.
- Phai bat dau cau dau tien bang: "Theo du lieu noi bo cua Chanh Viet,".
''';
      }

      final suggestions = await _listKnowledgeDocumentNames(limit: 5);
      if (suggestions.isEmpty) {
        return input;
      }

      return '''
$input

[GOI_Y_TAI_LIEU_NOI_BO]
${suggestions.map((name) => '- $name').join('\n')}
[/GOI_Y_TAI_LIEU_NOI_BO]

YEU_CAU_TRA_LOI:
- Neu chua co ket qua khop truc tiep, hay goi y nguoi dung chon san pham/chu de gan nhat tu GOI_Y_TAI_LIEU_NOI_BO.
- Khong ket luan "he thong khong co thong tin" khi GOI_Y_TAI_LIEU_NOI_BO khong rong.
''';
    } catch (_) {
      return input;
    }
  }

  Object? _decodeToolPayload(Map<String, dynamic>? result) {
    if (result == null) {
      return null;
    }
    final content = result['content'];
    if (content is! List || content.isEmpty) {
      return null;
    }
    for (final item in content) {
      if (item is! Map) {
        continue;
      }
      final text = item['text'];
      if (text is! String) {
        continue;
      }
      final trimmed = text.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return null;
        }
      }
      return trimmed;
    }
    return null;
  }

  Future<void> _injectKnowledgeForVoice(String text) async {
    if (!_isConnected ||
        _knowledgeVoiceInFlight ||
        !_shouldUseKnowledgeContext(text)) {
      return;
    }
    final normalized = _normalize(text);
    if (normalized.length < 3 || normalized.length > 280) {
      return;
    }
    final now = DateTime.now();
    if (_lastKnowledgeVoiceQuery == normalized &&
        now.difference(_lastKnowledgeVoiceAt) < _knowledgeVoiceCooldown) {
      return;
    }

    _knowledgeVoiceInFlight = true;
    _lastKnowledgeVoiceQuery = normalized;
    _lastKnowledgeVoiceAt = now;
    try {
      final snippets = await _searchKnowledgeSnippets(
        text,
        topK: _forceKnowledgeModeEnabled ? 1 : 3,
        maxSnippetChars: 1400,
        includeFullContent: true,
      );
      final normalizedQuestion = _normalizeQuestionForAgent(text);
      var knowledgeBlock = '';
      var hasDirectMatch = false;
      if (snippets.isNotEmpty) {
        knowledgeBlock = snippets.join('\n');
        hasDirectMatch = true;
      } else {
        final suggestions = await _listKnowledgeDocumentNames(limit: 5);
        if (suggestions.isEmpty) {
          return;
        }
        knowledgeBlock = suggestions.map((name) => '- $name').join('\n');
      }

      if (knowledgeBlock.isEmpty) {
        return;
      }

      final assistPrompt =
          '''
$_knowledgeMarker
Cau hoi nguoi dung: "$text"
 Cau hoi chuan hoa: "$normalizedQuestion"
 Quy uoc alias: "cha vi", "chai vi", "tra vi", "cha vi", "chá vi" deu la "Chavi".
${hasDirectMatch ? 'Du lieu noi bo lien quan:' : 'Danh sach tai lieu hien co (goi y):'}
$knowledgeBlock
YEU_CAU_TRA_LOI:
- Neu co du lieu lien quan, bat buoc uu tien du lieu noi bo o tren.
- KHONG duoc noi "khong tim thay", "khong co thong tin", hoac "co the ban nham ten" khi da co du lieu lien quan.
- Neu chua khop truc tiep, goi y nguoi dung chon san pham/chu de gan nhat trong danh sach tai lieu.
- Khong tra loi "khong tim thay thong tin" khi danh sach tai lieu khong rong.
- Neu da co du lieu lien quan, phai bat dau cau dau tien bang: "Theo du lieu noi bo cua Chanh Viet,".
''';
      await _textService.sendTextRequest(assistPrompt, useTextType: true);
      AppLogger.event(
        'ChatRepository',
        'knowledge_voice_context_sent',
        fields: <String, Object?>{
          'matches': snippets.length,
          'mode': hasDirectMatch ? 'direct' : 'suggestion',
        },
        level: 'D',
      );
    } catch (_) {
      // Ignore knowledge assist failures to keep voice flow uninterrupted.
    } finally {
      _knowledgeVoiceInFlight = false;
    }
  }

  Future<List<String>> _searchKnowledgeSnippets(
    String query, {
    required int topK,
    required int maxSnippetChars,
    bool includeFullContent = false,
  }) async {
    final response = await _mcpHandleMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': _mcpRequestId++,
      'method': 'tools/call',
      'params': <String, dynamic>{
        'name': 'self.knowledge.search',
        'arguments': <String, dynamic>{'query': query, 'top_k': topK},
      },
    });
    if (response == null) {
      return const <String>[];
    }

    final error = response['error'];
    if (error is Map && error['message'] is String) {
      return const <String>[];
    }

    final result = response['result'];
    final payload = _decodeToolPayload(
      result is Map<String, dynamic>
          ? result
          : result is Map
          ? Map<String, dynamic>.from(result)
          : null,
    );
    if (payload is! Map) {
      return const <String>[];
    }

    final rows = payload['results'];
    if (rows is! List || rows.isEmpty) {
      return const <String>[];
    }

    final snippets = <String>[];
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final name = (row['name'] ?? '').toString().trim();
      final title = (row['title'] ?? '').toString().trim();
      final docType = (row['doc_type'] ?? '').toString().trim();
      final summary = (row['summary'] ?? '').toString().trim();
      final usage = (row['usage'] ?? '').toString().trim();
      final safetyNote = (row['safety_note'] ?? '').toString().trim();
      final fieldHitsRaw = row['field_hits'];
      final fieldHits = fieldHitsRaw is List
          ? fieldHitsRaw.map((item) => item.toString()).toList()
          : const <String>[];
      final snippet = (row['snippet'] ?? '').toString().trim();
      final content = (row['content'] ?? '').toString().trim();
      final selected = includeFullContent && content.isNotEmpty
          ? _extractRelevantContext(content: content, query: query)
          : snippet;
      if (selected.isEmpty) {
        continue;
      }
      final reduced = selected.length > maxSnippetChars
          ? '${selected.substring(0, maxSnippetChars)}...'
          : selected;
      final label = name.isEmpty ? 'tai_lieu' : name;
      final buffer = StringBuffer();
      buffer.writeln('[TAI_LIEU] $label');
      if (title.isNotEmpty) {
        buffer.writeln('[TITLE] $title');
      }
      if (docType.isNotEmpty) {
        buffer.writeln('[DOC_TYPE] $docType');
      }
      if (fieldHits.isNotEmpty) {
        buffer.writeln('[FIELD_HITS] ${fieldHits.join(', ')}');
      }
      if (summary.isNotEmpty) {
        buffer.writeln('[SUMMARY] $summary');
      }
      buffer.writeln('[CONTENT] $reduced');
      if (usage.isNotEmpty) {
        buffer.writeln('[USAGE] $usage');
      }
      if (safetyNote.isNotEmpty) {
        buffer.writeln('[SAFETY_NOTE] $safetyNote');
      }
      snippets.add(buffer.toString().trim());
    }
    return snippets;
  }

  String _extractRelevantContext({
    required String content,
    required String query,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final kdocSections = _parseKdocSections(trimmed);
    if (kdocSections != null) {
      final summary = (kdocSections['SUMMARY'] ?? '').trim();
      final body = (kdocSections['CONTENT'] ?? '').trim();
      final usage = (kdocSections['USAGE'] ?? '').trim();
      final safeNote = (kdocSections['SAFETY_NOTE'] ?? '').trim();
      final title = (kdocSections['TITLE'] ?? '').trim();
      final block = StringBuffer();
      if (title.isNotEmpty) {
        block.writeln(title);
      }
      if (summary.isNotEmpty) {
        block.writeln(summary);
      }
      if (body.isNotEmpty) {
        block.writeln(body);
      }
      if (usage.isNotEmpty) {
        block.writeln('Hướng dẫn: $usage');
      }
      if (safeNote.isNotEmpty) {
        block.writeln('Lưu ý: $safeNote');
      }
      final extracted = block.toString().trim();
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }

    final lines = trimmed.split('\n');
    if (lines.length <= 20) {
      return trimmed;
    }

    final foldedQuery = _normalizeForKnowledge(query);
    final tokens = foldedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toSet();
    if (tokens.isEmpty) {
      return trimmed;
    }

    var bestIndex = -1;
    var bestScore = -1;
    for (var i = 0; i < lines.length; i++) {
      final foldedLine = _normalizeForKnowledge(lines[i]);
      if (foldedLine.isEmpty) {
        continue;
      }
      var score = 0;
      if (foldedLine.contains(foldedQuery)) {
        score += 16;
      }
      for (final token in tokens) {
        if (foldedLine.contains(token)) {
          score += 2;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    if (bestIndex < 0) {
      return trimmed;
    }

    // Try extracting one clean product section delimited by separator lines.
    final section = _extractDelimitedSection(
      lines: lines,
      anchorIndex: bestIndex,
    );
    if (section != null && section.trim().isNotEmpty) {
      return section.trim();
    }

    // Fallback: local block around the strongest line.
    final start = (bestIndex - 2).clamp(0, lines.length - 1);
    final end = (bestIndex + 20).clamp(0, lines.length - 1);
    final block = lines.sublist(start, end + 1).join('\n').trim();
    return block.isEmpty ? trimmed : block;
  }

  String? _extractDelimitedSection({
    required List<String> lines,
    required int anchorIndex,
  }) {
    if (lines.isEmpty || anchorIndex < 0 || anchorIndex >= lines.length) {
      return null;
    }

    final separators = <int>[];
    for (var i = 0; i < lines.length; i++) {
      if (_isSeparatorLine(lines[i])) {
        separators.add(i);
      }
    }
    if (separators.length < 2) {
      return null;
    }

    int? prevSep;
    for (final sep in separators) {
      if (sep <= anchorIndex) {
        prevSep = sep;
      } else {
        break;
      }
    }
    if (prevSep == null) {
      return null;
    }

    var start = prevSep;
    final prevSepPos = separators.indexOf(prevSep);
    if (prevSepPos > 0 && prevSep - separators[prevSepPos - 1] <= 4) {
      start = separators[prevSepPos - 1];
    }

    int? firstAfterStart;
    int? secondAfterStart;
    for (final sep in separators) {
      if (sep <= start) {
        continue;
      }
      if (firstAfterStart == null) {
        firstAfterStart = sep;
        continue;
      }
      secondAfterStart = sep;
      break;
    }

    if (firstAfterStart == null) {
      return null;
    }
    final end = (secondAfterStart ?? lines.length) - 1;
    if (end <= start) {
      return null;
    }

    return lines.sublist(start, end + 1).join('\n');
  }

  bool _isSeparatorLine(String line) {
    final trimmed = line.trim();
    return trimmed.length >= 10 && trimmed.replaceAll('-', '').isEmpty;
  }

  Map<String, String>? _parseKdocSections(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    final lines = normalized.split('\n');
    final start = lines.indexWhere((line) => line.trim() == '=== KDOC:v1 ===');
    final end = lines.lastIndexWhere(
      (line) => line.trim() == '=== END_KDOC ===',
    );
    if (start < 0 || end <= start) {
      return null;
    }

    final sections = <String, String>{};
    String? currentKey;
    final buffer = <String>[];
    final sectionPattern = RegExp(r'^\s*\[([A-Z_]+)\]\s*$');

    void flush() {
      if (currentKey == null) {
        return;
      }
      final key = currentKey;
      sections[key] = buffer.join('\n').trim();
      buffer.clear();
    }

    for (var i = start + 1; i < end; i++) {
      final line = lines[i];
      final match = sectionPattern.firstMatch(line);
      if (match != null) {
        flush();
        currentKey = match.group(1);
        continue;
      }
      if (currentKey != null) {
        buffer.add(line);
      }
    }
    flush();
    return sections;
  }

  Future<List<String>> _listKnowledgeDocumentNames({required int limit}) async {
    final response = await _mcpHandleMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': _mcpRequestId++,
      'method': 'tools/call',
      'params': <String, dynamic>{
        'name': 'self.knowledge.list_documents',
        'arguments': <String, dynamic>{},
      },
    });
    if (response == null) {
      return const <String>[];
    }

    final error = response['error'];
    if (error is Map && error['message'] is String) {
      return const <String>[];
    }

    final result = response['result'];
    final payload = _decodeToolPayload(
      result is Map<String, dynamic>
          ? result
          : result is Map
          ? Map<String, dynamic>.from(result)
          : null,
    );
    if (payload is! Map) {
      return const <String>[];
    }

    final rows = payload['documents'];
    if (rows is! List || rows.isEmpty) {
      return const <String>[];
    }

    final names = <String>[];
    for (final row in rows) {
      if (row is! Map) {
        continue;
      }
      final name = (row['name'] ?? '').toString().trim();
      if (name.isEmpty) {
        continue;
      }
      names.add(name);
      if (names.length >= limit) {
        break;
      }
    }
    return names;
  }

  Uri? _resolveWebHostBaseUri() {
    final injected = _webHostBaseUriResolver?.call();
    if (injected != null) {
      return injected;
    }
    final state = LocalWebHostService.instance.state;
    final rawUrl = state.url;
    if (!state.isRunning || rawUrl == null || rawUrl.trim().isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(rawUrl.trim());
    if (parsed == null || parsed.scheme.isEmpty) {
      return null;
    }
    return Uri(
      scheme: parsed.scheme,
      host: '127.0.0.1',
      port: parsed.hasPort ? parsed.port : null,
      path: '/',
    );
  }

  String? _resolveLocalImageUrl(String rawUrl, Uri baseUri) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    Uri? parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      final sameHost = parsed.host == baseUri.host;
      final samePort = parsed.port == baseUri.port;
      if (!sameHost || !samePort) {
        return null;
      }
    } else {
      parsed = Uri.tryParse(baseUri.resolve(trimmed).toString());
    }

    if (parsed == null) {
      return null;
    }

    if (!parsed.path.startsWith('/api/documents/image/content')) {
      return null;
    }

    if (!parsed.queryParameters.containsKey('id')) {
      return null;
    }

    return baseUri.resolve('${parsed.path}?${parsed.query}').toString();
  }

  Future<void> _tryHandleLocalVolumeCommand(String text) async {
    final target = _extractVolumeTarget(text);
    if (target == null) {
      return;
    }
    AppLogger.event(
      'ChatRepository',
      'local_volume_detected',
      fields: <String, Object?>{'target': target},
      level: 'D',
    );

    final now = DateTime.now();
    if (_lastLocalVolumeTarget == target &&
        now.difference(_lastLocalVolumeAt) < const Duration(seconds: 3)) {
      return;
    }
    _lastLocalVolumeAt = now;
    _lastLocalVolumeTarget = target;

    try {
      final setResult = await _callMcpTool(
        name: 'self.audio_speaker.set_volume',
        arguments: <String, dynamic>{'volume': target},
      );
      if (!_isToolSuccess(setResult)) {
        return;
      }
      final statusResult = await _callMcpTool(name: 'self.get_device_status');
      final currentVolume = _extractCurrentVolume(statusResult);
      final shownVolume = currentVolume ?? target;
      _suppressVolumeFailureUntil = DateTime.now().add(
        const Duration(seconds: 10),
      );
      _responsesController.add(
        ChatResponse(
          text: 'Đã chỉnh âm lượng thiết bị về $shownVolume%.',
          isUser: false,
        ),
      );
      AppLogger.event(
        'ChatRepository',
        'local_volume_set',
        fields: <String, Object?>{'target': target, 'reported': currentVolume},
      );
    } catch (_) {
      // Ignore local volume fallback failures.
    }
  }

  Future<bool> _checkBlockedPhraseAndHandle(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final normalizedInput = _normalizeForKnowledge(trimmed);
    final localBlocked = _isBlockedTopicPhrase(normalizedInput);

    final response = await _callMcpTool(
      name: 'self.guard.blocked_phrase_check',
      arguments: <String, dynamic>{'text': trimmed},
    );
    final payload = _decodeToolPayload(response);
    if (payload is! Map) {
      if (localBlocked) {
        _applyBlockedResponse(text: trimmed, normalizedInput: normalizedInput);
        return true;
      }
      return false;
    }
    final blocked = payload['blocked'] == true;
    if (!blocked) {
      return false;
    }
    _applyBlockedResponse(
      text: trimmed,
      normalizedInput: normalizedInput,
      safeReply: (payload['response'] as String?)?.trim(),
    );
    return true;
  }

  int? _extractVolumeTarget(String text) {
    final normalized = _normalizeForKnowledge(text);
    final isVolumeIntent =
        normalized.contains('am luong') ||
        normalized.contains('volume') ||
        normalized.contains('vol ');
    if (!isVolumeIntent) {
      return null;
    }

    final number = RegExp(r'(\d{1,3})').firstMatch(normalized)?.group(1);
    if (number != null) {
      final parsed = int.tryParse(number);
      if (parsed != null) {
        return parsed.clamp(0, 100);
      }
    }

    if (normalized.contains('toi da') ||
        normalized.contains('max') ||
        normalized.contains('lon nhat')) {
      return 100;
    }
    if (normalized.contains('toi thieu') ||
        normalized.contains('min') ||
        normalized.contains('nho nhat')) {
      return 0;
    }
    return null;
  }

  Future<Map<String, dynamic>?> _callMcpTool({
    required String name,
    Map<String, dynamic> arguments = const <String, dynamic>{},
    bool logRequest = false,
  }) async {
    final requestId = _mcpRequestId++;
    if (logRequest) {
      AppLogger.event(
        'MCP',
        'request',
        fields: <String, Object?>{'method': 'tools/call', 'id': requestId},
      );
      AppLogger.log(
        'MCP',
        'request_body=${jsonEncode(<String, dynamic>{
          'jsonrpc': '2.0',
          'id': requestId,
          'method': 'tools/call',
          'params': <String, dynamic>{'name': name, 'arguments': arguments},
        })}',
      );
    } else {
      AppLogger.event(
        'ChatRepository',
        'mcp_tool_call',
        fields: <String, Object?>{
          'id': requestId,
          'tool': name,
          'arguments': arguments,
        },
        level: 'D',
      );
    }
    final response = await _mcpHandleMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'tools/call',
      'params': <String, dynamic>{'name': name, 'arguments': arguments},
    });
    if (response == null) {
      AppLogger.event(
        'ChatRepository',
        'mcp_tool_null_response',
        fields: <String, Object?>{'id': requestId, 'tool': name},
        level: 'D',
      );
      if (logRequest) {
        AppLogger.event(
          'MCP',
          'ignored',
          fields: <String, Object?>{
            'reason': 'null_response',
            'method': 'tools/call',
            'id': requestId,
          },
          level: 'W',
        );
      }
      return null;
    }
    final error = response['error'];
    if (error is Map && error['message'] is String) {
      AppLogger.event(
        'ChatRepository',
        'mcp_tool_error',
        fields: <String, Object?>{
          'id': requestId,
          'tool': name,
          'error': error['message'],
        },
        level: 'D',
      );
      if (logRequest) {
        AppLogger.event(
          'MCP',
          'response',
          fields: <String, Object?>{'id': response['id'], 'has_error': true},
          level: 'W',
        );
        AppLogger.log('MCP', 'response_body=${jsonEncode(response)}');
      }
      return null;
    }
    final result = response['result'];
    if (logRequest) {
      AppLogger.event(
        'MCP',
        'response',
        fields: <String, Object?>{'id': requestId, 'has_error': false},
      );
      AppLogger.log('MCP', 'response_body=${jsonEncode(response)}');
    } else {
      AppLogger.event(
        'ChatRepository',
        'mcp_tool_success',
        fields: <String, Object?>{'id': requestId, 'tool': name},
        level: 'D',
      );
    }
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      return Map<String, dynamic>.from(result);
    }
    return null;
  }

  bool _isToolSuccess(Map<String, dynamic>? result) {
    final payload = _decodeToolPayload(result);
    if (payload is String) {
      return payload.trim().toLowerCase() == 'true';
    }
    return false;
  }

  int? _extractCurrentVolume(Map<String, dynamic>? result) {
    final payload = _decodeToolPayload(result);
    if (payload is! Map) {
      return null;
    }
    final audio = payload['audio_speaker'];
    if (audio is! Map) {
      return null;
    }
    final volume = audio['volume'];
    if (volume is num) {
      return volume.toInt().clamp(0, 100);
    }
    return null;
  }

  bool _shouldSuppressVolumeFailureText(String text) {
    if (DateTime.now().isAfter(_suppressVolumeFailureUntil)) {
      return false;
    }
    final normalized = _normalizeForKnowledge(text);
    final isVolumeTopic =
        normalized.contains('am luong') || normalized.contains('volume');
    final isFailureOrDeflect =
        normalized.contains('khong the') ||
        normalized.contains('chua the') ||
        normalized.contains('khong dieu chinh duoc') ||
        normalized.contains('chua kha dung') ||
        normalized.contains('xin loi');
    return isVolumeTopic && isFailureOrDeflect;
  }

  bool _shouldSuppressBlockedTopicText(String text) {
    if (!_isBlockedSuppressionActive()) {
      return false;
    }
    final normalized = _normalizeForKnowledge(text);
    return _isBlockedTopicPhrase(normalized);
  }

  bool _isLalaSchoolPhrase(String normalized) {
    if (normalized.isEmpty) {
      return false;
    }
    return normalized.contains('la la school') ||
        normalized.contains('lalaschool');
  }

  bool _isBlockedTopicPhrase(String normalized) {
    if (normalized.isEmpty) {
      return false;
    }
    return _isLalaSchoolPhrase(normalized) ||
        normalized.contains('subscribe') ||
        normalized.contains('hay subscribe') ||
        normalized.contains('sub kenh') ||
        normalized.contains('hay sub') ||
        normalized.contains('dang ky kenh') ||
        normalized.contains('dang ky');
  }

  void _applyBlockedResponse({
    required String text,
    required String normalizedInput,
    String? safeReply,
  }) {
    final now = DateTime.now();
    if (_lastBlockedInput == normalizedInput &&
        now.difference(_lastBlockedReplyAt) < const Duration(seconds: 5)) {
      return;
    }
    _lastBlockedInput = normalizedInput;
    _lastBlockedReplyAt = now;
    _activateBlockedSuppression(const Duration(seconds: 12));

    final isLalaSchool = _isLalaSchoolPhrase(normalizedInput);
    final fallback =
        'Xin loi, minh chua nghe ro noi dung. Ban vui long dat lai cau hoi ngan gon de minh ho tro chinh xac hon.';
    final lalaReply =
        'Xin loi, minh nghe khong ro. Ban vui long noi lai giup minh nhe.';
    _responsesController.add(
      ChatResponse(
        text: isLalaSchool
            ? lalaReply
            : (safeReply?.isNotEmpty == true ? safeReply! : fallback),
      ),
    );
    AppLogger.event(
      'ChatRepository',
      'blocked_phrase_handled',
      fields: <String, Object?>{'input': text},
    );
  }

  bool _isBlockedSuppressionActive() {
    return DateTime.now().isBefore(_suppressBlockedTopicUntil);
  }

  void _activateBlockedSuppression(Duration duration) {
    final now = DateTime.now();
    _suppressBlockedTopicUntil = now.add(duration);
    _sessionCoordinator.setPlaybackSuppressed(true);
    _blockedSuppressionTimer?.cancel();
    _blockedSuppressionTimer = Timer(duration, _clearBlockedSuppressionIfReady);
  }

  void _clearBlockedSuppressionIfReady() {
    final now = DateTime.now();
    if (now.isBefore(_suppressBlockedTopicUntil)) {
      final delay = _suppressBlockedTopicUntil.difference(now);
      _blockedSuppressionTimer?.cancel();
      _blockedSuppressionTimer = Timer(delay, _clearBlockedSuppressionIfReady);
      return;
    }
    _sessionCoordinator.setPlaybackSuppressed(false);
  }

  bool _shouldUseKnowledgeContext(String text) {
    final normalized = _foldForIntent(_normalize(text));
    if (normalized.length < 4) {
      return false;
    }

    for (final keyword in _smallTalkKeywords) {
      if (normalized.contains(keyword)) {
        return false;
      }
    }

    for (final keyword in _knowledgeKeywords) {
      if (normalized.contains(keyword)) {
        return true;
      }
    }

    final words = normalized.split(' ').where((item) => item.isNotEmpty).length;
    final hasQuestionIntent =
        normalized.contains('cho toi') ||
        normalized.contains('toi muon') ||
        normalized.contains('toi can') ||
        normalized.contains('co the') ||
        normalized.contains('?');
    return hasQuestionIntent && words >= 5;
  }

  String _foldForIntent(String input) {
    return _normalizeForKnowledge(input);
  }

  String _normalizeForKnowledge(String input) {
    var output = input
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ầ', 'a')
        .replaceAll('ấ', 'a')
        .replaceAll('ậ', 'a')
        .replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('ằ', 'a')
        .replaceAll('ắ', 'a')
        .replaceAll('ặ', 'a')
        .replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ề', 'e')
        .replaceAll('ế', 'e')
        .replaceAll('ệ', 'e')
        .replaceAll('ể', 'e')
        .replaceAll('ễ', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ồ', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ờ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ử', 'u')
        .replaceAll('ữ', 'u')
        .replaceAll('ỳ', 'y')
        .replaceAll('ý', 'y')
        .replaceAll('ỵ', 'y')
        .replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y')
        .replaceAll('đ', 'd');

    final replacements = <RegExp, String>{
      RegExp(r'\bcha\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchai\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchabi\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\btranh\s*viet\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\bchanh\s*viet\b', caseSensitive: false): 'chanhviet',
    };
    for (final entry in replacements.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }

  bool _isGenericImageRequest(String text) {
    final normalized = _normalizeForKnowledge(text);
    if (normalized.isEmpty) {
      return false;
    }
    final padded = ' $normalized ';
    const phraseIntents = <String>[
      'hinh anh',
      'hinh san pham',
      'anh san pham',
      'xem anh',
      'xem hinh',
      'cho toi hinh',
      'cho toi hinh anh',
      'show image',
      'show images',
    ];
    for (final intent in phraseIntents) {
      if (padded.contains(' $intent ')) {
        return true;
      }
    }
    final tokens = normalized
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toSet();
    const tokenIntents = <String>{
      'hinh',
      'anh',
      'image',
      'images',
      'photo',
      'photos',
      'gallery',
    };
    return tokens.any(tokenIntents.contains);
  }

  String _normalizeQuestionForAgent(String input) {
    var output = _normalizeForKnowledge(input);
    final replacements = <RegExp, String>{
      RegExp(r'\bcha\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchai\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchabi\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bch[aá]\s*vi\b', caseSensitive: false): 'chavi',
    };
    for (final entry in replacements.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }
}

class _RecentText {
  _RecentText({required this.text, required this.at});

  final String text;
  final DateTime at;
}
