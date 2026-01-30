import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import '../../../../capabilities/voice/session_coordinator.dart';
import '../../../../capabilities/voice/transport_client.dart';
import '../../../../capabilities/voice/websocket_transport_client.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/entities/chat_response.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/logging/app_logger.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl({
    required SessionCoordinator sessionCoordinator,
  })  : _sessionCoordinator = sessionCoordinator,
        _responsesController = StreamController<ChatResponse>.broadcast(),
        _audioController = StreamController<List<int>>.broadcast(),
        _errorController = StreamController<Failure>.broadcast(),
        _speakingController = StreamController<bool>.broadcast();

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
  bool _isConnected = false;
  bool _isSpeaking = false;

  @override
  Stream<ChatResponse> get responses => _responsesController.stream;

  @override
  Stream<List<int>> get audioStream => _audioController.stream;

  @override
  Stream<Failure> get errors => _errorController.stream;

  @override
  Stream<bool> get speakingStream => _speakingController.stream;

  @override
  int get serverSampleRate => _sessionCoordinator.serverSampleRate;

  @override
  Future<Result<bool>> connect(ChatConfig config) async {
    if (_isConnected) {
      return Result.success(true);
    }
    if (config.url.isEmpty || config.accessToken.isEmpty) {
      return Result.failure(
        const Failure(message: 'Thiếu thông tin kết nối'),
      );
    }
    _lastConfig = config;
    _logMessage('connect started');

    _transport = WebsocketTransportClient(
      deviceInfo: config.deviceInfo,
      url: config.url,
      accessToken: config.accessToken,
    );

    final opened = await _sessionCoordinator.connect(_transport!);
    if (!opened) {
      _logMessage('connect failed: openAudioChannel returned false');
      return Result.failure(
        const Failure(message: 'Không thể kết nối WebSocket'),
      );
    }
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
        _logMessage('network error: $error');
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
    await _sessionCoordinator.disconnect();
    _transport = null;
  }

  @override
  Future<void> startListening() async {
    await _sessionCoordinator.startListening();
  }

  @override
  Future<void> stopListening() async {
    await _sessionCoordinator.stopListening();
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
    final payload = <String, dynamic>{
      'type': 'text',
      'text': text,
      'session_id': _transport?.sessionId ?? '',
    };
    await _sessionCoordinator.sendText(jsonEncode(payload));
    return Result.success(true);
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
          _responsesController.add(ChatResponse(text: text, isUser: false));
        }
      }
      return;
    }

    if (type == 'llm') {
      return;
    }

    if (type == 'stt') {
      if (_isSpeaking) {
        return;
      }
      final text = json['text'] as String? ?? '';
      if (text.isNotEmpty) {
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

  void _logMessage(String message) {
    AppLogger.log('ChatRepository', message);
  }
}
