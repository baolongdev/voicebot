import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../../../capabilities/protocol/websocket_protocol.dart';
import '../../../../capabilities/protocol/protocol.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/entities/chat_response.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/logging/app_logger.dart';

class ChatRepositoryImpl implements ChatRepository {
  ChatRepositoryImpl()
      : _responsesController = StreamController<ChatResponse>.broadcast(),
        _audioController = StreamController<List<int>>.broadcast(),
        _errorController = StreamController<Failure>.broadcast(),
        _speakingController = StreamController<bool>.broadcast();

  final StreamController<ChatResponse> _responsesController;
  final StreamController<List<int>> _audioController;
  final StreamController<Failure> _errorController;
  final StreamController<bool> _speakingController;

  WebsocketProtocol? _protocol;
  StreamSubscription<Map<String, dynamic>>? _jsonSubscription;
  StreamSubscription<List<int>>? _audioSubscription;
  StreamSubscription<String>? _errorSubscription;
  ChatConfig? _lastConfig;
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
  int get serverSampleRate => _protocol?.serverSampleRate ?? -1;

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

    _protocol = WebsocketProtocol(
      deviceInfo: config.deviceInfo,
      url: config.url,
      accessToken: config.accessToken,
    );

    final opened = await _protocol!.openAudioChannel();
    if (!opened) {
      _logMessage('connect failed: openAudioChannel returned false');
      return Result.failure(
        const Failure(message: 'Không thể kết nối WebSocket'),
      );
    }
    _isConnected = true;

    _jsonSubscription = _protocol!.incomingJsonStream.stream.listen(
      _handleIncomingJson,
      onError: (_) {
        _errorController.add(const Failure(message: 'Lỗi nhận dữ liệu'));
      },
    );
    _audioSubscription = _protocol!.incomingAudioStream.stream.listen(
      (data) => _audioController.add(data),
      onError: (_) {
        _errorController.add(const Failure(message: 'Lỗi nhận âm thanh'));
      },
    );
    _errorSubscription = _protocol!.networkErrorStream.stream.listen(
      (error) {
        _logMessage('network error: $error');
        _errorController.add(Failure(message: error));
      },
    );

    return Result.success(true);
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _setSpeaking(false);
    await _jsonSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _errorSubscription?.cancel();
    _jsonSubscription = null;
    _audioSubscription = null;
    _errorSubscription = null;
    _protocol?.dispose();
    _protocol = null;
  }

  @override
  Future<void> startListening() async {
    await _protocol?.sendStartListening(ListeningMode.autoStop);
  }

  @override
  Future<void> stopListening() async {
    await _protocol?.sendStopListening();
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
      'session_id': _protocol?.sessionId ?? '',
    };
    await _protocol?.sendText(jsonEncode(payload));
    return Result.success(true);
  }

  @override
  Future<void> sendAudio(List<int> data) async {
    if (data.isEmpty) {
      return;
    }
    await _protocol?.sendAudio(Uint8List.fromList(data));
  }

  void _handleIncomingJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    if (type == 'tts') {
      final state = json['state'] as String? ?? '';
      if (state == 'start' || state == 'sentence_start') {
        _setSpeaking(true);
      }
      if (state == 'stop') {
        _setSpeaking(false);
        return;
      }
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
    if (_isSpeaking == speaking) {
      return;
    }
    _isSpeaking = speaking;
    _speakingController.add(speaking);
  }

  void _logMessage(String message) {
    AppLogger.log('ChatRepository', message);
  }
}
