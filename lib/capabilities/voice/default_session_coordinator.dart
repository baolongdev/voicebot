import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart' as opus_dart;

import '../../core/audio/audio_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/throttle.dart';
import '../mcp/mcp_server.dart';
import '../protocol/protocol.dart';
import 'audio_input.dart';
import 'audio_output.dart';
import 'session_coordinator.dart';
import 'transport_client.dart';

class DefaultSessionCoordinator implements SessionCoordinator {
  DefaultSessionCoordinator({
    required AudioInput audioInput,
    required AudioOutput audioOutput,
  })  : _audioInput = audioInput,
        _audioOutput = audioOutput;

  final AudioInput _audioInput;
  final AudioOutput _audioOutput;

  final StreamController<Map<String, dynamic>> _jsonController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Uint8List> _audioController =
      StreamController<Uint8List>.broadcast();
  final StreamController<double> _incomingLevelController =
      StreamController<double>.broadcast();
  final StreamController<double> _outgoingLevelController =
      StreamController<double>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

  final McpServer _mcpServer = McpServer();
  TransportClient? _transport;
  StreamSubscription<Map<String, dynamic>>? _jsonSubscription;
  StreamSubscription<Uint8List>? _audioSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<List<num>>? _decodeSubscription;
  StreamSubscription<Uint8List>? _encodeSubscription;
  StreamController<Uint8List>? _opusInputController;

  final BytesBuilder _playbackBuffer = BytesBuilder(copy: false);
  int _playbackFrameBytes = 0;
  int _playbackMinBytes = 0;
  bool _playbackStarted = false;
  int _playbackSampleRate = AudioConfig.sampleRate;
  bool _isListening = false;
  bool _canSendAudio = false;
  bool _isSpeaking = false;
  ListeningMode _listeningMode = ListeningMode.autoStop;
  int _speakingEpoch = 0;
  int _sentAudioFrames = 0;
  int _receivedAudioFrames = 0;
  final Throttler _sendLogThrottle = Throttler(25000);
  final Throttler _recvLogThrottle = Throttler(25000);
  int _lastIncomingLevelMs = 0;
  int _lastOutgoingLevelMs = 0;

  @override
  Stream<Map<String, dynamic>> get incomingJson => _jsonController.stream;

  @override
  Stream<Uint8List> get incomingAudio => _audioController.stream;

  @override
  Stream<double> get incomingLevel => _incomingLevelController.stream;

  @override
  Stream<double> get outgoingLevel => _outgoingLevelController.stream;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  Stream<bool> get speaking => _speakingController.stream;

  @override
  int get serverSampleRate => _transport?.serverSampleRate ?? -1;

  @override
  ListeningMode get listeningMode => _listeningMode;

  @override
  Future<bool> connect(TransportClient transport) async {
    try {
      await disconnect().timeout(const Duration(milliseconds: 500));
    } catch (_) {}
    _transport = transport;
    AppLogger.event(
      'SessionCoordinator',
      'connect_start',
    );
    final connected = await _transport!.connect();
    if (!connected) {
      AppLogger.event(
        'SessionCoordinator',
        'connect_failed',
      );
      _transport = null;
      return false;
    }
    AppLogger.event(
      'SessionCoordinator',
      'connect_success',
    );

    await _setupPlayback();
    _setupDecoder();

    _jsonSubscription = _transport!.jsonStream.listen(_handleIncomingJson);
    _audioSubscription = _transport!.audioStream.listen(_handleIncomingAudio);
    _errorSubscription = _transport!.errorStream.listen(_handleError);
    return true;
  }

  @override
  Future<void> disconnect() async {
    _canSendAudio = false;
    _isListening = false;
    _isSpeaking = false;
    _speakingEpoch += 1;
    _playbackBuffer.clear();
    _playbackStarted = false;
    _sentAudioFrames = 0;
    _receivedAudioFrames = 0;
    _emitIncomingLevel(0);
    _emitOutgoingLevel(0);
    _lastIncomingLevelMs = 0;
    _lastOutgoingLevelMs = 0;

    await _cancelSubscription(_encodeSubscription);
    await _cancelSubscription(_decodeSubscription);
    _encodeSubscription = null;
    _decodeSubscription = null;
    await _stopAudioInput();
    _audioOutput.dispose();
    _opusInputController?.close();
    _opusInputController = null;

    await _cancelSubscription(_jsonSubscription);
    await _cancelSubscription(_audioSubscription);
    await _cancelSubscription(_errorSubscription);
    _jsonSubscription = null;
    _audioSubscription = null;
    _errorSubscription = null;

    await _disconnectTransport();
    _transport = null;
  }

  Future<void> _cancelSubscription(StreamSubscription? subscription) async {
    if (subscription == null) {
      return;
    }
    try {
      await subscription.cancel().timeout(const Duration(milliseconds: 200));
    } catch (_) {
      // Ignore cancel errors/timeouts to keep teardown moving.
    }
  }

  Future<void> _stopAudioInput() async {
    try {
      await _audioInput.stop().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Ignore stop errors/timeouts to keep teardown moving.
    }
  }

  Future<void> _disconnectTransport() async {
    try {
      await _transport?.disconnect().timeout(const Duration(milliseconds: 500));
    } catch (_) {
      // Ignore transport disconnect errors/timeouts to keep teardown moving.
    }
  }

  @override
  Future<void> startListening({bool enableMic = true}) async {
    if (_transport == null) {
      return;
    }
    if (_isListening) {
      _canSendAudio = enableMic;
      if (enableMic) {
        _startEncodingIfNeeded();
      }
      return;
    }
    await _transport!.startListening(_listeningMode);
    _isListening = true;
    _canSendAudio = enableMic;
    if (enableMic) {
      _startEncodingIfNeeded();
    }
    AppLogger.event('SessionCoordinator', 'listen_start');
  }

  @override
  Future<void> stopListening() async {
    if (_transport == null) {
      return;
    }
    _canSendAudio = false;
    if (!_isListening) {
      return;
    }
    await _transport!.stopListening();
    await _encodeSubscription?.cancel();
    _encodeSubscription = null;
    await _audioInput.stop();
    _isListening = false;
    AppLogger.event('SessionCoordinator', 'listen_stop');
  }

  Future<void> _pauseListeningLocal() async {
    if (_transport == null) {
      return;
    }
    _canSendAudio = false;
    if (_encodeSubscription != null) {
      await _encodeSubscription?.cancel();
      _encodeSubscription = null;
    }
    await _audioInput.stop();
    _isListening = false;
    AppLogger.event('SessionCoordinator', 'listen_pause');
  }

  @override
  Future<void> sendText(String text) async {
    await _transport?.sendText(text);
  }

  @override
  Future<void> sendAudio(List<int> data) async {
    if (data.isEmpty) {
      return;
    }
    await _transport?.sendAudio(Uint8List.fromList(data));
  }

  @override
  void setListeningMode(ListeningMode mode) {
    if (_listeningMode == mode) {
      return;
    }
    _listeningMode = mode;
    AppLogger.event(
      'SessionCoordinator',
      'listen_mode',
      fields: <String, Object?>{'mode': mode.name},
      level: 'I',
    );
  }

  Future<void> _setupPlayback() async {
    var playbackSampleRate =
        serverSampleRate > 0 ? serverSampleRate : AudioConfig.sampleRate;
    if (Platform.isWindows) {
      AppLogger.log(
        'SessionCoordinator',
        'windows playback sampleRate=$playbackSampleRate',
      );
    }
    _playbackSampleRate = playbackSampleRate;
    _playbackFrameBytes = (playbackSampleRate *
            AudioConfig.frameDurationMs *
            AudioConfig.channels *
            2) ~/
        1000;
    _playbackMinBytes = _playbackFrameBytes * 3;
    _playbackStarted = false;
    await _audioOutput.start(
      sampleRate: playbackSampleRate,
      channels: AudioConfig.channels,
      frameDurationMs: AudioConfig.frameDurationMs,
    );
  }

  void _setupDecoder() {
    _decodeSubscription?.cancel();
    _decodeSubscription = null;
    _opusInputController?.close();
    _opusInputController = StreamController<Uint8List>();
    try {
      _decodeSubscription = _opusInputController!.stream
          .cast<Uint8List?>()
          .transform(
            opus_dart.StreamOpusDecoder.bytes(
              floatOutput: false,
              sampleRate: _playbackSampleRate,
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
    } catch (e) {
      AppLogger.log('SessionCoordinator', 'opus decoder init failed: $e');
      _decodeSubscription = null;
    }
  }

  void _startEncodingIfNeeded() {
    if (_encodeSubscription != null) {
      return;
    }
    final pcmStream = _audioInput.start().map((pcm) {
      _emitOutgoingLevel(_estimateLevelFromPcmChunk(pcm));
      return pcm;
    });
    try {
      _encodeSubscription = pcmStream
          .cast<List<int>>()
          .transform(
            opus_dart.StreamOpusEncoder<int>.bytes(
              floatInput: false,
              frameTime: opus_dart.FrameTime.ms60,
              sampleRate: _audioInput.sampleRate,
              channels: _audioInput.channels,
              application: opus_dart.Application.audio,
              copyOutput: true,
              fillUpLastFrame: true,
            ),
          )
          .listen((encoded) async {
            if (encoded.isNotEmpty && _canSendAudio) {
              _sentAudioFrames += 1;
              if (_sentAudioFrames % 50 == 0 && _sendLogThrottle.shouldRun()) {
                AppLogger.event(
                  'SessionCoordinator',
                  'audio_send',
                  fields: <String, Object?>{
                    'frames': _sentAudioFrames,
                    'bytes': encoded.length,
                  },
                  level: 'D',
                );
              }
              await _transport?.sendAudio(Uint8List.fromList(encoded));
            }
          });
    } catch (e) {
      AppLogger.log('SessionCoordinator', 'opus encoder init failed: $e');
      _encodeSubscription = null;
    }
  }

  void _handleIncomingJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    if (type == 'mcp') {
      unawaited(_handleMcpMessage(json));
      return;
    }
    if (type == 'tts') {
      final state = json['state'] as String? ?? '';
      if (state == 'start' || state == 'sentence_start') {
        _handleSpeakingChanged(true);
      } else if (state == 'stop') {
        _handleSpeakingChanged(false);
      }
    }
    _jsonController.add(json);
  }

  Future<void> _handleMcpMessage(Map<String, dynamic> json) async {
    final payload = json['payload'];
    if (payload is! Map<String, dynamic>) {
      return;
    }
    AppLogger.log(
      'MCP',
      'request=${jsonEncode(payload)}',
      level: 'D',
    );
    final response = await _mcpServer.handleMessage(payload);
    if (response == null) {
      return;
    }
    final sessionId =
        _transport?.sessionId ?? (json['session_id'] as String? ?? '');
    if (sessionId.isEmpty) {
      return;
    }
    final envelope = <String, dynamic>{
      'session_id': sessionId,
      'type': 'mcp',
      'payload': response,
    };
    await sendText(jsonEncode(envelope));
    AppLogger.log(
      'MCP',
      'response=${jsonEncode(response)}',
      level: 'D',
    );
  }

  void _handleIncomingAudio(Uint8List data) {
    _audioController.add(data);
    if (data.isEmpty || _opusInputController == null) {
      return;
    }
    _receivedAudioFrames += 1;
    if (_receivedAudioFrames % 50 == 0 && _recvLogThrottle.shouldRun()) {
      AppLogger.event(
        'SessionCoordinator',
        'audio_recv',
        fields: <String, Object?>{
          'frames': _receivedAudioFrames,
          'bytes': data.length,
        },
        level: 'D',
      );
    }
    _opusInputController!.add(Uint8List.fromList(data));
  }

  void _handleError(String error) {
    _canSendAudio = false;
    _isListening = false;
    if (_isSpeaking) {
      _speakingEpoch += 1;
      _isSpeaking = false;
      _speakingController.add(false);
    }
    if (_encodeSubscription != null) {
      unawaited(_encodeSubscription!.cancel());
      _encodeSubscription = null;
    }
    unawaited(_audioInput.stop());
    AppLogger.event(
      'SessionCoordinator',
      'transport_error',
      fields: <String, Object?>{'message': error},
      level: 'E',
    );
    _errorController.add(error);
  }

  Future<void> _handleSpeakingChanged(bool speaking) async {
    if (_transport == null) {
      return;
    }
    _speakingEpoch += 1;
    final epoch = _speakingEpoch;
    if (_isSpeaking == speaking) {
      return;
    }
    _isSpeaking = speaking;
    _speakingController.add(speaking);
    if (speaking) {
      await _pauseListeningLocal();
      _audioOutput.resetBuffer();
      return;
    }

    AppLogger.log('SessionCoordinator', 'waiting for TTS to stop');
    await _audioOutput.flushBufferedPlayback();
    await _audioOutput.waitForPlaybackCompletion();
    AppLogger.log('SessionCoordinator', 'TTS stopped');
    if (epoch != _speakingEpoch) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await startListening();
    AppLogger.log('SessionCoordinator', 'listen restarted after tts stop');
  }

  void _enqueuePcmForPlayback(Uint8List pcm) {
    _emitIncomingLevel(_estimateLevelFromPcmChunk(pcm));
    if (_playbackFrameBytes <= 0) {
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
      _audioOutput.enqueue(Uint8List.fromList(frame));
      offset += _playbackFrameBytes;
    }
    if (offset < buffer.length) {
      _playbackBuffer.add(Uint8List.sublistView(buffer, offset));
    }
  }

  double _estimateLevelFromPcmChunk(List<int> bytes) {
    if (bytes.isEmpty) {
      return 0;
    }
    final length = bytes.length - (bytes.length % 2);
    if (length <= 0) {
      return 0;
    }
    var sumSquares = 0.0;
    for (var i = 0; i < length; i += 2) {
      final lo = bytes[i];
      final hi = bytes[i + 1];
      var sample = (hi << 8) | lo;
      if (sample >= 32768) {
        sample -= 65536;
      }
      final normalized = sample / 32768.0;
      sumSquares += normalized * normalized;
    }
    final rms = math.sqrt(sumSquares / (length / 2));
    if (rms.isNaN || rms.isInfinite) {
      return 0;
    }
    return rms.clamp(0.0, 1.0);
  }

  void _emitIncomingLevel(double level) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastIncomingLevelMs < 80) {
      return;
    }
    _lastIncomingLevelMs = now;
    _incomingLevelController.add(level);
  }

  void _emitOutgoingLevel(double level) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastOutgoingLevelMs < 80) {
      return;
    }
    _lastOutgoingLevelMs = now;
    _outgoingLevelController.add(level);
  }
}
