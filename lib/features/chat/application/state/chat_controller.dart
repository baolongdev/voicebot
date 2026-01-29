import 'dart:async';

import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:opus_dart/opus_dart.dart' as opus_dart;

import '../../../../core/errors/failure.dart';
import '../../../../core/audio/audio_config.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../capabilities/audio/recorder/audio_recorder.dart';
import '../../../../capabilities/audio/player/opus_stream_player.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_response.dart';
import '../usecases/connect_chat_usecase.dart';
import '../usecases/disconnect_chat_usecase.dart';
import '../usecases/get_server_sample_rate_usecase.dart';
import '../usecases/load_chat_config_usecase.dart';
import '../usecases/observe_chat_audio_usecase.dart';
import '../usecases/observe_chat_errors_usecase.dart';
import '../usecases/observe_chat_responses_usecase.dart';
import '../usecases/observe_chat_speaking_usecase.dart';
import '../usecases/send_audio_frame_usecase.dart';
import '../usecases/send_chat_message_usecase.dart';
import '../usecases/start_listening_usecase.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required LoadChatConfigUseCase loadConfig,
    required ConnectChatUseCase connect,
    required DisconnectChatUseCase disconnect,
    required GetServerSampleRateUseCase getServerSampleRate,
    required SendChatMessageUseCase sendMessage,
    required SendAudioFrameUseCase sendAudioFrame,
    required StartListeningUseCase startListening,
    required ObserveChatResponsesUseCase observeResponses,
    required ObserveChatAudioUseCase observeAudio,
    required ObserveChatErrorsUseCase observeErrors,
    required ObserveChatSpeakingUseCase observeSpeaking,
  })  : _loadConfig = loadConfig,
        _connect = connect,
        _disconnect = disconnect,
        _getServerSampleRate = getServerSampleRate,
        _sendMessage = sendMessage,
        _sendAudioFrame = sendAudioFrame,
        _startListening = startListening,
        _observeResponses = observeResponses,
        _observeAudio = observeAudio,
        _observeErrors = observeErrors,
        _observeSpeaking = observeSpeaking;

  final LoadChatConfigUseCase _loadConfig;
  final ConnectChatUseCase _connect;
  final DisconnectChatUseCase _disconnect;
  final GetServerSampleRateUseCase _getServerSampleRate;
  final SendChatMessageUseCase _sendMessage;
  final SendAudioFrameUseCase _sendAudioFrame;
  final StartListeningUseCase _startListening;
  final ObserveChatResponsesUseCase _observeResponses;
  final ObserveChatAudioUseCase _observeAudio;
  final ObserveChatErrorsUseCase _observeErrors;
  final ObserveChatSpeakingUseCase _observeSpeaking;

  final List<ChatMessage> _messages = <ChatMessage>[];
  bool _isSending = false;
  bool _isSpeaking = false;
  String? _connectionError;

  StreamSubscription<ChatResponse>? _responseSubscription;
  StreamSubscription<List<int>>? _audioSubscription;
  StreamSubscription<Failure>? _errorSubscription;
  StreamSubscription<bool>? _speakingSubscription;
  StreamSubscription<Uint8List>? _recordingSubscription;
  StreamSubscription<List<num>>? _decodeSubscription;
  StreamSubscription<Uint8List>? _encodeSubscription;

  AudioRecorder? _recorder;
  OpusStreamPlayer? _player;
  StreamController<Uint8List?>? _decodedController;
  StreamController<Uint8List>? _opusInputController;
  final BytesBuilder _playbackBuffer = BytesBuilder(copy: false);
  int _playbackFrameBytes = 0;
  bool _playbackStarted = false;
  int _playbackMinBytes = 0;
  Timer? _retryTimer;
  int _speakingEpoch = 0;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  String? get connectionError => _connectionError;
  bool get isSpeaking => _isSpeaking;

  Future<void> initialize() async {
    await _attachStreams();
    await _connectWithConfig();
  }

  Future<void> _attachStreams() async {
    await _responseSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _errorSubscription?.cancel();
    await _speakingSubscription?.cancel();

    _responseSubscription = _observeResponses().listen((response) {
      if (response.text.trim().isEmpty) {
        return;
      }
      _messages.add(
        ChatMessage(
          text: response.text,
          isUser: response.isUser,
          timestamp: DateTime.now(),
        ),
      );
      _logMessage(response.isUser ? '>> ${response.text}' : '<< ${response.text}');
      final audioBytes = response.audioBytes;
      if (audioBytes != null && audioBytes.isNotEmpty) {
        _handleIncomingAudio(audioBytes);
      }
      notifyListeners();
    });

    _audioSubscription = _observeAudio().listen(_handleIncomingAudio);

    _errorSubscription = _observeErrors().listen((failure) {
      _connectionError = failure.message;
      notifyListeners();
    });

    _speakingSubscription = _observeSpeaking().listen(_handleSpeakingChanged);
  }

  Future<void> _connectWithConfig() async {
    final configResult = await _loadConfig();
    if (!configResult.isSuccess || configResult.data == null) {
      _connectionError = configResult.failure?.message ?? 'Không thể kết nối';
      _logMessage('connect skipped: ${_connectionError ?? 'missing config'}');
      _scheduleRetry();
      notifyListeners();
      return;
    }

    _retryTimer?.cancel();
    final result = await _connect(configResult.data!);
    if (!result.isSuccess) {
      _connectionError = result.failure?.message ?? 'Không thể kết nối';
      _scheduleRetry();
      notifyListeners();
      return;
    }
    await _startAudioPipeline();
  }

  Future<void> _startAudioPipeline() async {
    if (_recordingSubscription != null) {
      return;
    }

    final serverSampleRate = _getServerSampleRate();
    final playbackSampleRate =
        serverSampleRate > 0 ? serverSampleRate : AudioConfig.sampleRate;
    _playbackFrameBytes = (playbackSampleRate *
            AudioConfig.frameDurationMs *
            AudioConfig.channels *
            2) ~/
        1000;
    _playbackMinBytes = _playbackFrameBytes * 3;
    _playbackStarted = false;

    _decodedController = StreamController<Uint8List?>();
    _player = OpusStreamPlayer(
      playbackSampleRate,
      AudioConfig.channels,
      AudioConfig.frameDurationMs,
    );
    await _player!.start(_decodedController!.stream);

    _opusInputController = StreamController<Uint8List>();
    _decodeSubscription = _opusInputController!.stream
        .cast<Uint8List?>()
        .transform(
          opus_dart.StreamOpusDecoder.bytes(
            floatOutput: false,
            sampleRate: playbackSampleRate,
            channels: AudioConfig.channels,
            copyOutput: true,
            forwardErrorCorrection: false,
          ),
        )
        .listen((pcm) {
          if (pcm is Uint8List && pcm.isNotEmpty) {
            _enqueuePcmForPlayback(pcm);
          }
        });

    _recorder = AudioRecorder(
      AudioConfig.sampleRate,
      AudioConfig.channels,
      AudioConfig.frameDurationMs,
    );
    _encodeSubscription = _recorder!
        .startRecording()
        .cast<List<int>>()
        .transform(
          opus_dart.StreamOpusEncoder<int>.bytes(
            floatInput: false,
            frameTime: opus_dart.FrameTime.ms60,
            sampleRate: AudioConfig.sampleRate,
            channels: AudioConfig.channels,
            application: opus_dart.Application.audio,
            copyOutput: true,
            fillUpLastFrame: true,
          ),
        )
        .listen((encoded) async {
          if (encoded.isNotEmpty) {
            await _sendAudioFrame(encoded);
          }
        });

    await _startListening();
  }

  Future<void> _handleIncomingAudio(List<int> data) async {
    if (data.isEmpty || _opusInputController == null) {
      return;
    }
    _opusInputController!.add(Uint8List.fromList(data));
  }

  void setRecordingPaused(bool paused) {
    // No-op in Kotlin-aligned flow (mic not paused during TTS).
  }

  Future<void> _handleSpeakingChanged(bool speaking) async {
    _speakingEpoch += 1;
    final epoch = _speakingEpoch;
    _isSpeaking = speaking;
    if (speaking) {
      notifyListeners();
      return;
    }

    _logMessage('waiting for TTS to stop');
    await _player?.waitForPlaybackCompletion();
    _logMessage('TTS stopped');
    if (epoch != _speakingEpoch) {
      return;
    }
    await _startListening();
    _logMessage('listen restarted after tts stop');
    notifyListeners();
  }
  void _enqueuePcmForPlayback(Uint8List pcm) {
    if (_decodedController == null || _playbackFrameBytes <= 0) {
      return;
    }
    _playbackBuffer.add(pcm);
    var buffer = _playbackBuffer.takeBytes();
    if (!_playbackStarted && buffer.length < _playbackMinBytes) {
      _playbackBuffer.add(buffer);
      return;
    }
    _playbackStarted = true;
    var offset = 0;
    while (buffer.length - offset >= _playbackFrameBytes) {
      final frame = Uint8List.sublistView(
        buffer,
        offset,
        offset + _playbackFrameBytes,
      );
      _decodedController!.add(Uint8List.fromList(frame));
      offset += _playbackFrameBytes;
    }
    if (offset < buffer.length) {
      _playbackBuffer.add(Uint8List.sublistView(buffer, offset));
    }
  }

  void markTtsStopped() {
    _isSpeaking = false;
  }

  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _messages.add(
      ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ),
    );
    _logMessage('[User] $trimmed');
    _isSending = true;
    notifyListeners();

    try {
      final result = await _sendMessage(trimmed);
      if (!result.isSuccess && result.failure != null) {
        _connectionError = result.failure?.message;
      }
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _audioSubscription?.cancel();
    _errorSubscription?.cancel();
    _recordingSubscription?.cancel();
    _encodeSubscription?.cancel();
    _decodeSubscription?.cancel();
    _recorder?.stopRecording();
    _player?.release();
    _decodedController?.close();
    _opusInputController?.close();
    _playbackBuffer.clear();
    _playbackStarted = false;
    _retryTimer?.cancel();
    _disconnect();
    super.dispose();
  }

  void _scheduleRetry() {
    if (_retryTimer != null) {
      return;
    }
    const retryDelay = Duration(seconds: 2);
    _retryTimer = Timer(retryDelay, () {
      _retryTimer = null;
      _connectWithConfig();
    });
  }

  void _logMessage(String message) {
    AppLogger.log('ChatViewModel', message);
  }
}
