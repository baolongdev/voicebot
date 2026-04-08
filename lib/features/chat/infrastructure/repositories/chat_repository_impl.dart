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
import '../../../../core/config/default_settings.dart';
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
    LocalWebHostState Function()? webHostStateResolver,
    Future<Map<String, dynamic>?> Function(Map<String, dynamic> payload)?
    mcpHandleMessage,
  }) : _sessionCoordinator = sessionCoordinator,
       _webHostBaseUriResolver = webHostBaseUriResolver,
       _webHostStateResolver = webHostStateResolver,
       _mcpHandleMessage =
           mcpHandleMessage ??
           ((payload) => McpServer.shared.handleMessage(
             payload,
             caller: McpCallerType.internal,
           )),
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
  final LocalWebHostState Function()? _webHostStateResolver;
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
  TextSendMode _textSendMode =
      DefaultSettingsRegistry.current.chat.textSendMode;
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
  final List<_RecentText> _recentBotTexts = <_RecentText>[];
  static const Duration _recentTextWindow = Duration(seconds: 10);
  static const Duration _knowledgeVoiceCooldown = Duration(seconds: 6);
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
          const GenericFailure(message: 'Thiếu thông tin kết nối'),
        );
      }
    } else if (config.transportType == TransportType.mqtt &&
        config.mqttConfig == null) {
      return Result.failure(
        const GenericFailure(
          message: 'Chưa có cấu hình MQTT',
          code: _missingMqttCode,
        ),
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
      return Result.failure(
        const GenericFailure(message: 'Không thể chọn transport'),
      );
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
        GenericFailure(
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
        _errorController.add(const GenericFailure(message: 'Lỗi nhận dữ liệu'));
      },
    );
    _audioSubscription = _sessionCoordinator.incomingAudio.listen(
      (data) => _audioController.add(data),
      onError: (_) {
        _errorController.add(
          const GenericFailure(message: 'Lỗi nhận âm thanh'),
        );
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
      _errorController.add(GenericFailure(message: error));
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
    _textSendMode = mode;
  }

  @override
  Future<Result<bool>> sendGreeting(String text) async {
    final input = text.trim();
    if (input.isEmpty) {
      return Result.failure(const GenericFailure(message: 'Nội dung trống'));
    }
    if (!_isConnected) {
      if (_lastConfig == null) {
        return Result.failure(
          const GenericFailure(message: 'Chưa cấu hình kết nối'),
        );
      }
      final result = await connect(_lastConfig!);
      if (!result.isSuccess) {
        return result;
      }
    }
    final useTextType = _textSendMode == TextSendMode.text;
    AppLogger.event(
      'ChatRepository',
      'send_greeting',
      fields: <String, Object?>{
        'mode': _textSendMode.name,
        'length': input.length,
      },
      level: 'D',
    );
    return _textService.sendTextRequest(input, useTextType: useTextType);
  }

  @override
  Future<Result<bool>> sendMessage(String text) async {
    final input = text.trim();
    if (input.isEmpty) {
      return Result.failure(const GenericFailure(message: 'Nội dung trống'));
    }
    if (!_isConnected) {
      if (_lastConfig == null) {
        return Result.failure(
          const GenericFailure(message: 'Chưa cấu hình kết nối'),
        );
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
    return _textService.sendTextRequest(textWithKnowledge, useTextType: true);
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
      topK: topKValue,
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
      return docImages.take(maxImageCount).toList(growable: false);
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
        return docImages.take(maxImageCount).toList(growable: false);
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
        return docImages.take(maxImageCount).toList(growable: false);
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
        return docImages.take(maxImageCount).toList(growable: false);
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

      final rankedImages = imagesById.values.toList(growable: false)
        ..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          if (byScore != 0) {
            return byScore;
          }
          final aMillis = a.createdAt?.millisecondsSinceEpoch ?? 0;
          final bMillis = b.createdAt?.millisecondsSinceEpoch ?? 0;
          return bMillis.compareTo(aMillis);
        });
      final selected = rankedImages.take(maxImageCount).toList(growable: false);
      if (selected.isNotEmpty) {
        _lastImageContextQuery = effectiveQuery;
        _lastImageContextAt = now;
      }
      AppLogger.event(
        'ChatRepository',
        'related_images_loaded',
        fields: <String, Object?>{
          'query': inputQuery,
          'effective_query': effectiveQuery,
          'images': selected.length,
          'latency_ms': DateTime.now().difference(startedAt).inMilliseconds,
        },
        level: 'D',
      );
      return selected;
    } catch (error) {
      if (docImages.isNotEmpty) {
        return docImages.take(maxImageCount).toList(growable: false);
      }
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
    required int topK,
    required int maxImages,
  }) async {
    final normalized = _normalizeForKnowledge(query);
    if (normalized.isEmpty) {
      return const <RelatedChatImage>[];
    }
    final matches = await _searchKnowledgeMatches(
      query,
      topK: topK,
      maxSnippetChars: 480,
      includeFullContent: false,
    );
    final directMatches = _selectDirectKnowledgeMatches(
      matches,
      analysis: _analyzeKnowledgeQuestion(query),
    );
    if (directMatches.isEmpty) {
      return const <RelatedChatImage>[];
    }

    List<RelatedChatImage> bestImages = const <RelatedChatImage>[];
    var bestSetScore = -1;
    for (final match in directMatches) {
      final references = <String>[
        if (match.title.trim().isNotEmpty) match.title.trim(),
        if (match.name.trim().isNotEmpty) match.name.trim(),
      ];
      final images = await _listImagesForReferences(
        references,
        maxImages: maxImages,
      );
      if (images.isEmpty) {
        continue;
      }
      final setScore =
          (match.score * 1000) +
          (match.coverageRatio * 100).round() * 10 +
          images.length;
      if (setScore > bestSetScore) {
        bestSetScore = setScore;
        bestImages = images.take(maxImages).toList(growable: false);
      }
    }
    return bestImages;
  }

  Future<List<RelatedChatImage>> _listImagesForReferences(
    List<String> references, {
    required int maxImages,
  }) async {
    final imagesById = <String, RelatedChatImage>{};
    for (final reference in references) {
      if (imagesById.length >= maxImages) {
        break;
      }
      final images = await _listImagesForDocument(
        reference,
        maxImages: maxImages,
      );
      for (final image in images) {
        imagesById.putIfAbsent(image.id, () => image);
        if (imagesById.length >= maxImages) {
          break;
        }
      }
    }
    return imagesById.values.toList(growable: false);
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
      final matches = await _searchKnowledgeMatches(
        query,
        topK: _forceKnowledgeModeEnabled ? 2 : 3,
        maxSnippetChars: 980,
        includeFullContent: true,
      );
      final normalizedQuestion = _normalizeQuestionForAgent(query);
      final queryAnalysis = _analyzeKnowledgeQuestion(query);
      final directMatches = _selectDirectKnowledgeMatches(
        matches,
        analysis: queryAnalysis,
      );
      if (directMatches.isNotEmpty) {
        AppLogger.event(
          'ChatRepository',
          'knowledge_context_attached',
          fields: <String, Object?>{'matches': directMatches.length},
          level: 'D',
        );

        final contextBlock = _buildKnowledgeEvidenceBlock(
          directMatches,
          query: query,
          analysis: queryAnalysis,
        );
        return '''
$input

[DU_LIEU_NOI_BO_LIEN_QUAN]
$contextBlock
[/DU_LIEU_NOI_BO_LIEN_QUAN]

THONG_TIN_BO_SUNG:
- Cau hoi goc: "$query"
- Cau hoi chuan hoa: "$normalizedQuestion"
- Loai cau hoi: ${queryAnalysis.kind}
- Uu tien muc KDOC: ${queryAnalysis.preferredSections.isEmpty ? 'auto' : queryAnalysis.preferredSections.join(', ')}
- Quy uoc alias: "cha vi", "chai vi", "tra vi", "cha vi", "chá vi" deu la "Chavi".

YEU_CAU_TRA_LOI:
- Chi tra loi dung phan nguoi dung dang hoi.
- Chi su dung du kien co trong DU_LIEU_NOI_BO_LIEN_QUAN.
- UU tien doc muc "HO_SO_TAI_LIEU_DAY_DU" de lay tong quan, sau do dung "BANG_CHUNG_TRUC_TIEP" va "DOAN_LIEN_QUAN_NHAT" de chot cau tra loi dung trong tam.
- Xem "TAI_LIEU_1" la nguon chinh; chi dung tai lieu khac neu no bo sung truc tiep cung chu de dang hoi.
- Neu co "BANG_CHUNG_TRUC_TIEP", uu tien dung no truoc vi day la phan sat nhat voi cau hoi.
- Neu DU_LIEU_NOI_BO_LIEN_QUAN da co muc phu hop voi chu de duoc hoi (vi du: An toan thuc pham, Thi truong, Quy trinh, Nguyen lieu), khong duoc noi la "khong co thong tin".
- Neu "DOAN_LIEN_QUAN_NHAT" hoac "BANG_CHUNG_TRUC_TIEP" khong rong, khong duoc mo dau bang "Xin loi" hoac noi la "chua co thong tin".
- Neu tai lieu chi du cho mot phan cau hoi, tra loi phan co bang chung truoc roi noi ngan gon phan nao chua co du lieu.
- Khong suy dien them tac dung, thong so, chinh sach, gia tri hoac ket luan ngoai tai lieu.
- Khong duoc chuyen sang mot san pham, tai lieu, hoac chu de khac neu ten do khong xuat hien trong "BANG_CHUNG_TRUC_TIEP" hoac "HO_SO_TAI_LIEU_DAY_DU".
- Khong duoc tu them thong tin suc khoe, thanh phan hoa hoc, cong dung y hoc hoac loi ich sinh hoc (vi du vitamin C, axit citric, thanh nhiet, ho tro tieu hoa) neu chung khong co trong bang chung.
- Khong liet ke thong tin khong lien quan truc tiep toi cau hoi.
- Khong xung "chung toi" hoac dong vai doanh nghiep neu tai lieu chi la ho so/gioi thieu.
- Tra loi tu nhien bang tieng Viet, khong nhac toi ten block hay metadata noi bo.
${_buildKnowledgeAnswerGuidance(queryAnalysis)}
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
- Chua co bang chung du manh de tra loi chac chan.
- Hay hoi lai ngan gon de lam ro san pham hoac chu de gan nhat trong GOI_Y_TAI_LIEU_NOI_BO.
- Khong tu khang dinh thong tin ngoai tai lieu.
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
      final matches = await _searchKnowledgeMatches(
        text,
        topK: _forceKnowledgeModeEnabled ? 2 : 3,
        maxSnippetChars: 980,
        includeFullContent: true,
      );
      final normalizedQuestion = _normalizeQuestionForAgent(text);
      final queryAnalysis = _analyzeKnowledgeQuestion(text);
      var knowledgeBlock = '';
      var hasDirectMatch = false;
      final directMatches = _selectDirectKnowledgeMatches(
        matches,
        analysis: queryAnalysis,
      );
      if (directMatches.isNotEmpty) {
        knowledgeBlock = _buildKnowledgeEvidenceBlock(
          directMatches,
          query: text,
          analysis: queryAnalysis,
        );
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
Loai cau hoi: ${queryAnalysis.kind}
Uu tien muc KDOC: ${queryAnalysis.preferredSections.isEmpty ? 'auto' : queryAnalysis.preferredSections.join(', ')}
Quy uoc alias: "cha vi", "chai vi", "tra vi", "cha vi", "chá vi" deu la "Chavi".
${hasDirectMatch ? 'Du lieu noi bo lien quan:' : 'Danh sach tai lieu hien co (goi y):'}
$knowledgeBlock
YEU_CAU_TRA_LOI:
- Chi tra loi dung trong tam cau hoi.
- Neu co du lieu lien quan, chi dung du kien o tren va khong suy dien them.
- UU tien doc muc "HO_SO_TAI_LIEU_DAY_DU" de lay tong quan, sau do dung "BANG_CHUNG_TRUC_TIEP" va "DOAN_LIEN_QUAN_NHAT" de chot cau tra loi.
- Xem "TAI_LIEU_1" la nguon chinh; chi dung tai lieu khac neu no bo sung truc tiep cung chu de dang hoi.
- Neu co "BANG_CHUNG_TRUC_TIEP", uu tien dung no truoc vi day la phan sat nhat voi cau hoi.
- Neu du lieu o tren da co muc phu hop voi cau hoi (vi du: An toan thuc pham, Thi truong, Quy trinh, Nguyen lieu), khong duoc noi "khong co thong tin".
- Neu "DOAN_LIEN_QUAN_NHAT" hoac "BANG_CHUNG_TRUC_TIEP" khong rong, khong duoc mo dau bang "Xin loi" hoac noi la "chua co thong tin".
- Neu du lieu chi du mot phan, tra loi phan co bang chung truoc roi noi ngan gon phan nao chua co du lieu.
- Neu chua khop truc tiep, hoi lai de lam ro san pham/chu de gan nhat trong danh sach tai lieu.
- Bo qua cac cau tra loi chung chung truoc do neu chua dua tren du lieu noi bo.
- Khong duoc chuyen sang mot san pham, tai lieu, hoac chu de khac neu ten do khong xuat hien trong "BANG_CHUNG_TRUC_TIEP" hoac "HO_SO_TAI_LIEU_DAY_DU".
- Khong duoc tu them thong tin suc khoe, thanh phan hoa hoc, cong dung y hoc hoac loi ich sinh hoc (vi du vitamin C, axit citric, thanh nhiet, ho tro tieu hoa) neu chung khong co trong bang chung.
- Khong xung "chung toi" hoac dong vai doanh nghiep neu tai lieu chi la ho so/gioi thieu.
${_buildKnowledgeAnswerGuidance(queryAnalysis)}
''';
      await _textService.sendTextRequest(assistPrompt, useTextType: true);
      AppLogger.event(
        'ChatRepository',
        'knowledge_voice_context_sent',
        fields: <String, Object?>{
          'matches': directMatches.isNotEmpty ? directMatches.length : 0,
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

  Future<List<_KnowledgeMatch>> _searchKnowledgeMatches(
    String query, {
    required int topK,
    required int maxSnippetChars,
    bool includeFullContent = false,
  }) async {
    final searchQuery = _normalizeQuestionForAgent(query);
    final response = await _mcpHandleMessage(<String, dynamic>{
      'jsonrpc': '2.0',
      'id': _mcpRequestId++,
      'method': 'tools/call',
      'params': <String, dynamic>{
        'name': 'self.knowledge.search',
        'arguments': <String, dynamic>{'query': searchQuery, 'top_k': topK},
      },
    });
    if (response == null) {
      return const <_KnowledgeMatch>[];
    }

    final error = response['error'];
    if (error is Map && error['message'] is String) {
      return const <_KnowledgeMatch>[];
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
      return const <_KnowledgeMatch>[];
    }

    final rows = payload['results'];
    if (rows is! List || rows.isEmpty) {
      return const <_KnowledgeMatch>[];
    }

    final matches = <_KnowledgeMatch>[];
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
      final matchReasonsRaw = row['match_reasons'];
      final matchReasons = matchReasonsRaw is List
          ? matchReasonsRaw.map((item) => item.toString()).toList()
          : const <String>[];
      final snippet = (row['snippet'] ?? '').toString().trim();
      final content = (row['content'] ?? '').toString().trim();
      final selected = includeFullContent && content.isNotEmpty
          ? _extractRelevantContext(
              content: content,
              query: query,
              preferredFields: fieldHits,
            )
          : snippet;
      final overview = content.isNotEmpty
          ? _extractKnowledgeOverview(content)
          : summary;
      if (selected.isEmpty) {
        continue;
      }
      final reduced = selected.length > maxSnippetChars
          ? '${selected.substring(0, maxSnippetChars)}...'
          : selected;
      matches.add(
        _KnowledgeMatch(
          name: name.isEmpty ? 'tai_lieu' : name,
          title: title,
          docType: docType,
          summary: summary,
          usage: usage,
          safetyNote: safetyNote,
          fieldHits: fieldHits,
          matchReasons: matchReasons,
          overview: overview,
          rawContent: content,
          content: reduced,
          score: (row['score'] as num?)?.toInt() ?? 0,
          coverageRatio: (row['coverage_ratio'] as num?)?.toDouble() ?? 0,
          confidence: (row['confidence'] ?? 'low').toString().trim(),
          exactMatch: row['exact_match'] == true,
        ),
      );
    }
    return matches;
  }

  List<_KnowledgeMatch> _selectDirectKnowledgeMatches(
    List<_KnowledgeMatch> matches, {
    required _KnowledgeQueryAnalysis analysis,
  }) {
    if (matches.isEmpty) {
      return const <_KnowledgeMatch>[];
    }
    final direct = matches
        .where((match) {
          if (match.exactMatch) {
            return true;
          }
          if (match.confidence == 'high') {
            return true;
          }
          if (match.confidence == 'medium' && match.coverageRatio >= 0.45) {
            return true;
          }
          if (match.coverageRatio >= 0.35 &&
              (match.fieldHits.contains('content') ||
                  match.fieldHits.contains('usage') ||
                  match.fieldHits.any(
                    (field) =>
                        field == 'market' ||
                        field == 'services' ||
                        field == 'regulations',
                  ))) {
            return true;
          }
          return false;
        })
        .take(2)
        .toList(growable: false);
    if (direct.isNotEmpty) {
      return _refineDirectKnowledgeMatches(direct, analysis: analysis);
    }
    final fallback = matches
        .where((match) {
          if (match.coverageRatio < 0.45) {
            return false;
          }
          return match.fieldHits.contains('summary') ||
              match.fieldHits.contains('content') ||
              match.fieldHits.contains('usage') ||
              match.fieldHits.contains('faq');
        })
        .take(1)
        .toList(growable: false);
    return _refineDirectKnowledgeMatches(fallback, analysis: analysis);
  }

  List<_KnowledgeMatch> _refineDirectKnowledgeMatches(
    List<_KnowledgeMatch> matches, {
    required _KnowledgeQueryAnalysis analysis,
  }) {
    if (matches.length <= 1) {
      return matches;
    }

    final preferredDocTypes = _preferredDocTypesForKnowledgeQuestion(analysis);
    final filtered = preferredDocTypes.isEmpty
        ? matches
        : matches
              .where((match) => preferredDocTypes.contains(match.docType))
              .toList(growable: false);
    final candidates = filtered.isEmpty ? matches : filtered;
    final top = candidates.first;

    if (analysis.kind != 'general') {
      return <_KnowledgeMatch>[top];
    }

    if (top.exactMatch || top.coverageRatio >= 0.75) {
      return <_KnowledgeMatch>[top];
    }

    if (candidates.length >= 2) {
      final second = candidates[1];
      if (top.docType != second.docType || top.score - second.score >= 18) {
        return <_KnowledgeMatch>[top];
      }
    }

    return candidates.take(2).toList(growable: false);
  }

  Set<String> _preferredDocTypesForKnowledgeQuestion(
    _KnowledgeQueryAnalysis analysis,
  ) {
    if (analysis.kind == 'overview' || analysis.kind == 'strategy') {
      return <String>{'company_profile', 'info'};
    }
    if (analysis.kind == 'products') {
      return <String>{'product', 'company_profile', 'info'};
    }
    return const <String>{};
  }

  String _buildKnowledgeEvidenceBlock(
    List<_KnowledgeMatch> matches, {
    required String query,
    required _KnowledgeQueryAnalysis analysis,
  }) {
    final buffer = StringBuffer();
    var totalChars = 0;
    for (var i = 0; i < matches.length; i++) {
      final match = matches[i];
      final fullDossier = _buildKnowledgeFullDossier(match);
      final directEvidence = _buildKnowledgeDirectEvidence(
        match,
        query: query,
        preferredSections: analysis.preferredSections,
      );
      final relevantExcerpt = _trimInline(match.content, maxChars: 520);
      final segment = StringBuffer();
      if (i > 0) {
        segment.writeln();
      }
      segment.writeln('[TAI_LIEU_${i + 1}]');
      segment.writeln(
        '- Ten: ${match.title.isEmpty ? match.name : match.title}',
      );
      if (match.docType.isNotEmpty) {
        segment.writeln('- Loai: ${match.docType}');
      }
      segment.writeln(
        '- Do phu hop: ${match.confidence} (${(match.coverageRatio * 100).round()}%)',
      );
      if (match.fieldHits.isNotEmpty) {
        segment.writeln('- Truong khop: ${match.fieldHits.join(', ')}');
      }
      if (match.summary.isNotEmpty) {
        segment.writeln(
          '- Tom tat: ${_trimInline(match.summary, maxChars: 180)}',
        );
      }
      if (fullDossier.isNotEmpty) {
        segment.writeln('[HO_SO_TAI_LIEU_DAY_DU]');
        segment.writeln(fullDossier);
        segment.writeln('[/HO_SO_TAI_LIEU_DAY_DU]');
      }
      if (directEvidence.isNotEmpty) {
        segment.writeln('[BANG_CHUNG_TRUC_TIEP]');
        segment.writeln(directEvidence);
        segment.writeln('[/BANG_CHUNG_TRUC_TIEP]');
      }
      segment.writeln('[DOAN_LIEN_QUAN_NHAT]');
      segment.writeln(relevantExcerpt);
      segment.writeln('[/DOAN_LIEN_QUAN_NHAT]');
      if (match.usage.isNotEmpty && !match.content.contains(match.usage)) {
        segment.writeln(
          '- Huong dan: ${_trimInline(match.usage, maxChars: 180)}',
        );
      }
      if (match.safetyNote.isNotEmpty) {
        segment.writeln(
          '- Luu y: ${_trimInline(match.safetyNote, maxChars: 180)}',
        );
      }
      final segmentText = segment.toString().trim();
      if (segmentText.isEmpty) {
        continue;
      }
      final candidate = totalChars == 0
          ? segmentText
          : '${buffer.toString()}\n\n$segmentText';
      if (candidate.length > 5200 && totalChars > 0) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(segmentText);
      totalChars = buffer.length;
    }
    return buffer.toString().trim();
  }

  String _buildKnowledgeDirectEvidence(
    _KnowledgeMatch match, {
    required String query,
    required List<String> preferredSections,
  }) {
    final raw = match.rawContent.trim();
    if (raw.isEmpty) {
      return '';
    }
    final sections = _parseKdocSections(raw);
    if (sections == null) {
      final excerpt = _extractBestExcerpt(
        content: raw,
        query: query,
        maxChars: 900,
      );
      return excerpt.isEmpty ? '' : excerpt;
    }

    final rankedSections = _rankDirectEvidenceSections(
      sections: sections,
      query: query,
      preferredSections: preferredSections,
    );
    if (rankedSections.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final candidate in rankedSections.take(2)) {
      final block = '[${candidate.key}]\n${candidate.value}'.trim();
      final candidateText = buffer.isEmpty
          ? block
          : '${buffer.toString()}\n\n$block';
      if (candidateText.length > 1800 && buffer.isNotEmpty) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(block);
    }
    return buffer.toString().trim();
  }

  String _buildKnowledgeFullDossier(_KnowledgeMatch match) {
    final raw = match.rawContent.trim();
    if (raw.isEmpty) {
      return match.overview;
    }
    final sections = _parseKdocSections(raw);
    if (sections == null) {
      return _trimInline(raw, maxChars: 2200);
    }

    final orderedKeys = <String>[
      'SUMMARY',
      'CONTENT',
      'USAGE',
      'FAQ',
      'MARKET',
      'SERVICES',
      'REGULATIONS',
      'RAW_MATERIALS',
      'PROCESS',
      'FOOD_SAFETY',
      'CORE_PRODUCTS',
      'SAFETY_NOTE',
      ...sections.keys.where(
        (key) =>
            key != 'DOC_ID' &&
            key != 'DOC_TYPE' &&
            key != 'TITLE' &&
            key != 'ALIASES' &&
            key != 'KEYWORDS' &&
            key != 'LAST_UPDATED' &&
            key != 'SUMMARY' &&
            key != 'CONTENT' &&
            key != 'USAGE' &&
            key != 'FAQ' &&
            key != 'MARKET' &&
            key != 'SERVICES' &&
            key != 'REGULATIONS' &&
            key != 'RAW_MATERIALS' &&
            key != 'PROCESS' &&
            key != 'FOOD_SAFETY' &&
            key != 'CORE_PRODUCTS' &&
            key != 'SAFETY_NOTE',
      ),
    ];
    final seen = <String>{};
    final buffer = StringBuffer();
    for (final rawKey in orderedKeys) {
      final key = rawKey.toUpperCase();
      if (!seen.add(key)) {
        continue;
      }
      final value = (sections[key] ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      final nextBlock = '[${key.toUpperCase()}]\n$value'.trim();
      final candidate = buffer.isEmpty
          ? nextBlock
          : '${buffer.toString()}\n\n$nextBlock';
      if (candidate.length > 2200) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(nextBlock);
    }
    final built = buffer.toString().trim();
    if (built.isNotEmpty) {
      return built;
    }
    return _trimInline(raw, maxChars: 2200);
  }

  String _extractRelevantContext({
    required String content,
    required String query,
    List<String> preferredFields = const <String>[],
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final kdocSections = _parseKdocSections(trimmed);
    if (kdocSections != null) {
      final extracted = _extractRelevantKdocContext(
        sections: kdocSections,
        query: query,
        preferredFields: preferredFields,
      );
      if (extracted.isNotEmpty) {
        return extracted;
      }
    }

    return _extractBestExcerpt(content: trimmed, query: query, maxChars: 540);
  }

  String _extractKnowledgeOverview(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    final sections = _parseKdocSections(trimmed);
    if (sections == null) {
      return _trimInline(trimmed, maxChars: 1200);
    }

    final orderedKeys = <String>[
      'SUMMARY',
      'CONTENT',
      'USAGE',
      'MARKET',
      'SERVICES',
      'REGULATIONS',
      'RAW_MATERIALS',
      'PROCESS',
      'FOOD_SAFETY',
      'FAQ',
      'SAFETY_NOTE',
      ...sections.keys.where(
        (key) =>
            key != 'DOC_ID' &&
            key != 'DOC_TYPE' &&
            key != 'TITLE' &&
            key != 'ALIASES' &&
            key != 'KEYWORDS' &&
            key != 'LAST_UPDATED' &&
            key != 'SUMMARY' &&
            key != 'CONTENT' &&
            key != 'USAGE' &&
            key != 'MARKET' &&
            key != 'SERVICES' &&
            key != 'REGULATIONS' &&
            key != 'RAW_MATERIALS' &&
            key != 'PROCESS' &&
            key != 'FOOD_SAFETY' &&
            key != 'FAQ' &&
            key != 'SAFETY_NOTE',
      ),
    ];
    final seen = <String>{};
    final buffer = StringBuffer();
    for (final rawKey in orderedKeys) {
      final key = rawKey.toUpperCase();
      if (!seen.add(key)) {
        continue;
      }
      final value = (sections[key] ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      final nextBlock = '${_sectionLabel(key)}:\n$value'.trim();
      final candidate = buffer.isEmpty
          ? nextBlock
          : '${buffer.toString()}\n\n$nextBlock';
      if (candidate.length > 1200) {
        break;
      }
      if (buffer.isNotEmpty) {
        buffer.writeln();
        buffer.writeln();
      }
      buffer.write(nextBlock);
    }
    return buffer.toString().trim();
  }

  _KnowledgeQueryAnalysis _analyzeKnowledgeQuestion(String query) {
    final normalized = _normalizeForKnowledge(query);
    final padded = ' $normalized ';

    bool containsAny(List<String> phrases) {
      for (final phrase in phrases) {
        if (padded.contains(' ${_normalizeForKnowledge(phrase)} ')) {
          return true;
        }
      }
      return false;
    }

    if (containsAny(const <String>[
      'an toan thuc pham',
      'chung nhan',
      'chung chi',
      'haccp',
      'halal',
      'fda',
      'ocop',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'food_safety',
        preferredSections: <String>['FOOD_SAFETY', 'SAFETY_NOTE'],
      );
    }
    if (containsAny(const <String>[
      'thi truong',
      'kenh phan phoi',
      'phan phoi',
      'xuat khau',
      'noi dia',
      'ban o dau',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'market',
        preferredSections: <String>['MARKET', 'SERVICES'],
      );
    }
    if (containsAny(const <String>[
      'quy trinh',
      'san xuat',
      'che bien',
      'lam nhu the nao',
      'cong doan',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'process',
        preferredSections: <String>['PROCESS', 'RAW_MATERIALS', 'CONTENT'],
      );
    }
    if (containsAny(const <String>[
      'nguyen lieu',
      'dau vao',
      'vung trong',
      'nguon nguyen lieu',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'raw_materials',
        preferredSections: <String>['RAW_MATERIALS', 'PROCESS', 'CONTENT'],
      );
    }
    if (containsAny(const <String>[
      'san pham',
      'mat hang',
      'san pham chu luc',
      'danh muc san pham',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'products',
        preferredSections: <String>['CORE_PRODUCTS', 'CONTENT', 'SUMMARY'],
      );
    }
    if (containsAny(const <String>[
      'dinh huong phat trien',
      'dinh huong',
      'tam nhin',
      'su menh',
      'muc tieu',
      'chien luoc',
      'huong den',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'strategy',
        preferredSections: <String>['CONTENT', 'SUMMARY', 'MARKET'],
      );
    }
    if (containsAny(const <String>[
      'cong ty',
      'doanh nghiep',
      'gioi thieu',
      'tong quat',
      'tom tat',
      'ho so',
      'thong tin cong ty',
    ])) {
      return const _KnowledgeQueryAnalysis(
        kind: 'overview',
        preferredSections: <String>[
          'SUMMARY',
          'CONTENT',
          'CORE_PRODUCTS',
          'MARKET',
        ],
      );
    }
    return const _KnowledgeQueryAnalysis(
      kind: 'general',
      preferredSections: <String>[],
    );
  }

  String _buildKnowledgeAnswerGuidance(_KnowledgeQueryAnalysis analysis) {
    return switch (analysis.kind) {
      'overview' =>
        '- Vi day la cau hoi tong quat, hay tom tat 4-6 y cu the tu tai lieu nhu: ten doanh nghiep, linh vuc, quy mo, dia diem, san pham, thi truong neu co.',
      'strategy' =>
        '- Vi day la cau hoi ve dinh huong/tam nhin/muc tieu phat trien, hay uu tien muc CONTENT va SUMMARY, trich dung y noi ve dinh huong phat trien neu tai lieu co.',
      'food_safety' =>
        '- Vi day la cau hoi ve an toan thuc pham, hay uu tien muc FOOD_SAFETY va neu ro cac chung nhan, xep hang, hoac tieu chuan co trong tai lieu.',
      'market' =>
        '- Vi day la cau hoi ve thi truong/phan phoi, hay uu tien muc MARKET va tach ro kenh noi dia va thi truong xuat khau neu tai lieu co.',
      'process' =>
        '- Vi day la cau hoi ve quy trinh san xuat, hay mo ta theo tung buoc chinh trong muc PROCESS thay vi chi noi dia diem nha may.',
      'raw_materials' =>
        '- Vi day la cau hoi ve nguyen lieu, hay neu ro nguon nguyen lieu va cach lien ket vung trong neu tai lieu co.',
      'products' =>
        '- Vi day la cau hoi ve danh muc san pham, hay nhom cac san pham theo tung nhom chinh va neu san pham chu luc neu tai lieu co.',
      _ =>
        '- Neu cau hoi rong, duoc phep tra loi 3-6 y ngan gon mien la moi y deu co trong tai lieu.',
    };
  }

  String _extractRelevantKdocContext({
    required Map<String, String> sections,
    required String query,
    required List<String> preferredFields,
  }) {
    final selectedBlocks = <String>[];
    final summary = (sections['SUMMARY'] ?? '').trim();
    if (summary.isNotEmpty) {
      selectedBlocks.add('Tóm tắt: ${_trimInline(summary, maxChars: 220)}');
    }

    final candidates =
        <({String key, String label, String value, int score})>[];
    final orderedKeys = <String>[
      ...preferredFields,
      'CONTENT',
      'USAGE',
      'FAQ',
      'SAFETY_NOTE',
      ...sections.keys.where(
        (key) =>
            key != 'DOC_ID' &&
            key != 'DOC_TYPE' &&
            key != 'TITLE' &&
            key != 'ALIASES' &&
            key != 'KEYWORDS' &&
            key != 'SUMMARY' &&
            key != 'LAST_UPDATED',
      ),
    ];
    final seen = <String>{};
    for (final rawKey in orderedKeys) {
      final key = rawKey.toUpperCase();
      if (!seen.add(key)) {
        continue;
      }
      final value = (sections[key] ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      final score = _scoreContextBlock(key: key, content: value, query: query);
      if (score <= 0) {
        continue;
      }
      candidates.add((
        key: key,
        label: _sectionLabel(key),
        value: value,
        score: score,
      ));
    }

    candidates.sort((a, b) => b.score.compareTo(a.score));
    for (final candidate in candidates.take(2)) {
      final excerpt = _extractBestExcerpt(
        content: candidate.value,
        query: query,
        maxChars: 280,
      );
      if (excerpt.isEmpty) {
        continue;
      }
      selectedBlocks.add('${candidate.label}: $excerpt');
    }

    if (selectedBlocks.isNotEmpty) {
      return selectedBlocks.join('\n');
    }

    final body = (sections['CONTENT'] ?? '').trim();
    if (body.isNotEmpty) {
      return _extractBestExcerpt(content: body, query: query, maxChars: 420);
    }
    return '';
  }

  List<({String key, String value, int score})> _rankDirectEvidenceSections({
    required Map<String, String> sections,
    required String query,
    required List<String> preferredSections,
  }) {
    final orderedKeys = <String>[
      ...preferredSections,
      'CONTENT',
      'SUMMARY',
      'USAGE',
      'FAQ',
      ...sections.keys.where(
        (key) =>
            key != 'DOC_ID' &&
            key != 'DOC_TYPE' &&
            key != 'TITLE' &&
            key != 'ALIASES' &&
            key != 'KEYWORDS' &&
            key != 'LAST_UPDATED',
      ),
    ];
    final seen = <String>{};
    final candidates = <({String key, String value, int score})>[];
    for (final rawKey in orderedKeys) {
      final key = rawKey.toUpperCase();
      if (!seen.add(key)) {
        continue;
      }
      final value = (sections[key] ?? '').trim();
      if (value.isEmpty) {
        continue;
      }
      final score = _scoreContextBlock(key: key, content: value, query: query);
      if (score <= 0) {
        continue;
      }
      candidates.add((key: key, value: value, score: score));
    }
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates;
  }

  int _scoreContextBlock({
    required String key,
    required String content,
    required String query,
  }) {
    final foldedQuery = _normalizeForKnowledge(query);
    final foldedContent = _normalizeForKnowledge(content);
    if (foldedQuery.isEmpty) {
      return 0;
    }
    final tokens = foldedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toSet();
    var score = 0;
    if (foldedContent.isNotEmpty && foldedContent.contains(foldedQuery)) {
      score += 20;
    }
    for (final token in tokens) {
      if (foldedContent.isNotEmpty && foldedContent.contains(token)) {
        score += 3;
      }
    }
    final sectionIntentTerms = _sectionIntentTerms(key);
    if (sectionIntentTerms.isNotEmpty) {
      final normalizedSectionLabel = _normalizeForKnowledge(_sectionLabel(key));
      final hasSectionIntent = sectionIntentTerms.any(
        (term) => foldedQuery.contains(_normalizeForKnowledge(term)),
      );
      if (hasSectionIntent) {
        score += 24;
      }
      for (final token in tokens) {
        if (normalizedSectionLabel.contains(token)) {
          score += 4;
        }
      }
    }
    return score;
  }

  String _extractBestExcerpt({
    required String content,
    required String query,
    required int maxChars,
  }) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    if (trimmed.length <= maxChars) {
      return trimmed;
    }

    final lines = trimmed
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !_isSeparatorLine(line))
        .toList(growable: false);
    if (lines.isEmpty) {
      return _trimInline(trimmed, maxChars: maxChars);
    }

    final foldedQuery = _normalizeForKnowledge(query);
    final tokens = foldedQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.length >= 2)
        .toSet();

    var bestIndex = -1;
    var bestScore = -1;
    for (var i = 0; i < lines.length; i++) {
      final foldedLine = _normalizeForKnowledge(lines[i]);
      if (foldedLine.isEmpty) {
        continue;
      }
      var score = 0;
      if (foldedLine.contains(foldedQuery)) {
        score += 18;
      }
      for (final token in tokens) {
        if (foldedLine.contains(token)) {
          score += 3;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    if (bestIndex < 0 || bestScore <= 0) {
      return _trimInline(trimmed, maxChars: maxChars);
    }

    final chosen = <String>[];
    var currentChars = 0;
    final start = (bestIndex - 1).clamp(0, lines.length - 1);
    final end = (bestIndex + 2).clamp(0, lines.length - 1);
    for (var i = start; i <= end; i++) {
      final line = lines[i];
      final nextChars = currentChars + line.length + (chosen.isEmpty ? 0 : 1);
      if (nextChars > maxChars) {
        break;
      }
      chosen.add(line);
      currentChars = nextChars;
    }

    final excerpt = chosen.join('\n').trim();
    if (excerpt.isEmpty) {
      return _trimInline(trimmed, maxChars: maxChars);
    }
    return excerpt;
  }

  String _trimInline(String input, {required int maxChars}) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars)}...';
  }

  String _sectionLabel(String key) {
    return switch (key) {
      'CONTENT' => 'Nội dung liên quan',
      'USAGE' => 'Hướng dẫn',
      'FAQ' => 'Hỏi đáp',
      'SAFETY_NOTE' => 'Lưu ý',
      'RAW_MATERIALS' => 'Nguyên liệu',
      'PROCESS' => 'Quy trình',
      'FOOD_SAFETY' => 'An toàn thực phẩm',
      'MARKET' => 'Thị trường',
      'SERVICES' => 'Dịch vụ',
      'REGULATIONS' => 'Quy định',
      _ => key,
    };
  }

  List<String> _sectionIntentTerms(String key) {
    return switch (key) {
      'FOOD_SAFETY' => const <String>[
        'an toan thuc pham',
        'chung nhan',
        'chung chi',
        'kiem dinh',
        'tieu chuan',
        'halal',
        'haccp',
        'fda',
        'ocop',
      ],
      'MARKET' => const <String>[
        'thi truong',
        'kenh phan phoi',
        'phan phoi',
        'xuat khau',
        'noi dia',
        'ban o dau',
        'kenh ban hang',
      ],
      'PROCESS' => const <String>[
        'quy trinh',
        'che bien',
        'san xuat',
        'lam nhu the nao',
      ],
      'CONTENT' => const <String>[
        'dinh huong phat trien',
        'dinh huong',
        'tam nhin',
        'su menh',
        'muc tieu',
        'chien luoc',
        'tong quat',
        'gioi thieu',
        'thong tin cong ty',
      ],
      'RAW_MATERIALS' => const <String>[
        'nguyen lieu',
        'dau vao',
        'vung trong',
        'nguon nguyen lieu',
      ],
      'CORE_PRODUCTS' => const <String>[
        'san pham',
        'san pham chu luc',
        'mat hang',
        'danh muc san pham',
      ],
      'SERVICES' => const <String>['dich vu', 'ho tro', 'hop tac'],
      'REGULATIONS' => const <String>[
        'quy dinh',
        'chinh sach',
        'dieu kien',
        'tieu chuan hop tac',
      ],
      _ => const <String>[],
    };
  }

  // End of class

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
    final state =
        _webHostStateResolver?.call() ?? LocalWebHostService.instance.state;
    return state.loopbackUri;
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
      RegExp(r'\bchami\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchamy\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bcha\s*mi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchami\s*garden\b', caseSensitive: false): 'chavi garden',
      RegExp(r'\bchamy\s*garden\b', caseSensitive: false): 'chavi garden',
      RegExp(r'\bcha\s*mi\s*garden\b', caseSensitive: false): 'chavi garden',
      RegExp(r'\bhuy\s*trinh\b', caseSensitive: false): 'quy trinh',
      RegExp(r'\bcanh\s*viet\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\bton\s*cat\b', caseSensitive: false): 'tong quat',
      RegExp(r'\btom\s*cat\b', caseSensitive: false): 'tom tat',
      RegExp(r'\bbo\s*tranh\b', caseSensitive: false): 'bot chanh',
      RegExp(r'\bbot\s*tranh\b', caseSensitive: false): 'bot chanh',
      RegExp(r'\bbo\s*chanh\b', caseSensitive: false): 'bot chanh',
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
      RegExp(r'\bchami\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchamy\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bcha\s*mi\b', caseSensitive: false): 'chavi',
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

class _KnowledgeMatch {
  const _KnowledgeMatch({
    required this.name,
    required this.title,
    required this.docType,
    required this.summary,
    required this.usage,
    required this.safetyNote,
    required this.fieldHits,
    required this.matchReasons,
    required this.overview,
    required this.rawContent,
    required this.content,
    required this.score,
    required this.coverageRatio,
    required this.confidence,
    required this.exactMatch,
  });

  final String name;
  final String title;
  final String docType;
  final String summary;
  final String usage;
  final String safetyNote;
  final List<String> fieldHits;
  final List<String> matchReasons;
  final String overview;
  final String rawContent;
  final String content;
  final int score;
  final double coverageRatio;
  final String confidence;
  final bool exactMatch;
}

class _KnowledgeQueryAnalysis {
  const _KnowledgeQueryAnalysis({
    required this.kind,
    required this.preferredSections,
  });

  final String kind;
  final List<String> preferredSections;
}
