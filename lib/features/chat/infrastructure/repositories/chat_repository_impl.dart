import 'dart:async';
import 'dart:typed_data';
import '../../../../capabilities/protocol/protocol.dart';
import '../../../../capabilities/voice/session_coordinator.dart';
import '../../../../capabilities/voice/transport_client.dart';
import '../../../../capabilities/voice/websocket_transport_client.dart';
import '../../../../capabilities/voice/mqtt_transport_client.dart';
import '../../../form/domain/models/server_form_data.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/entities/chat_response.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/throttle.dart';
import '../services/xiaozhi_text_service.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required SessionCoordinator sessionCoordinator,
  })  : _sessionCoordinator = sessionCoordinator,
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
  final List<_RecentText> _recentBotTexts = <_RecentText>[];
  static const Duration _recentTextWindow = Duration(seconds: 10);
  static const String _missingMqttCode = 'missing_mqtt';
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
      fields: <String, Object?>{
        'transport': config.transportType.name,
      },
    );

    _transport = _buildTransport(config);
    if (_transport == null) {
      return Result.failure(
        const Failure(message: 'Không thể chọn transport'),
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
      fields: <String, Object?>{
        'transport': config.transportType.name,
      },
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
    _errorSubscription = _sessionCoordinator.errors.listen(
      (error) {
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
      },
    );
    _speakingSubscription = _sessionCoordinator.speaking.listen(_setSpeaking);

    return Result.success(true);
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    await _jsonSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _speakingSubscription?.cancel();
    _jsonSubscription = null;
    _audioSubscription = null;
    _errorSubscription = null;
    _speakingSubscription = null;
    try {
      await _sessionCoordinator
          .disconnect()
          .timeout(const Duration(seconds: 1));
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
        return Result.failure(
          const Failure(message: 'Chưa cấu hình kết nối'),
        );
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
    if (!_isConnected) {
      if (_lastConfig == null) {
        return Result.failure(
          const Failure(message: 'Chưa cấu hình kết nối'),
        );
      }
      final result = await connect(_lastConfig!);
      if (!result.isSuccess) {
        return result;
      }
    }
    return _textService.sendTextRequest(text);
  }


  @override
  Future<void> sendAudio(List<int> data) async {
    await _sessionCoordinator.sendAudio(data);
  }

  void _handleIncomingJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    if (type == 'tts') {
      final state = json['state'] as String? ?? '';
      if (state == 'sentence_start') {
        final text = json['text'] as String? ?? '';
        if (text.isNotEmpty) {
          _rememberBotText(text);
          _responsesController.add(ChatResponse(text: text, isUser: false));
        }
      }
      return;
    }

    if (type == 'llm') {
      final emotion = json['emotion'] as String?;
      if (emotion != null && emotion.isNotEmpty) {
        _responsesController.add(
          ChatResponse(
            text: '',
            isUser: false,
            emotion: emotion,
          ),
        );
      }
      return;
    }

    if (type == 'stt') {
      final text = json['text'] as String? ?? '';
      if (text.isNotEmpty) {
        if (_isSpeaking && _isLikelyEcho(text)) {
          return;
        }
        _responsesController.add(ChatResponse(text: text, isUser: true));
      }
      return;
    }

    final text = json['text'] as String? ?? '';
    if (text.isNotEmpty) {
      _responsesController.add(ChatResponse(text: text, isUser: false));
    }
  }

  void dispose() {
    disconnect();
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
    _recentBotTexts.add(_RecentText(text: _normalize(text), at: DateTime.now()));
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

}

class _RecentText {
  _RecentText({required this.text, required this.at});

  final String text;
  final DateTime at;
}
