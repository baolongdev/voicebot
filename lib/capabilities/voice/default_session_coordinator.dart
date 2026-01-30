import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:opus_dart/opus_dart.dart' as opus_dart;

import '../../core/audio/audio_config.dart';
import '../../core/logging/app_logger.dart';
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
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();
  final StreamController<bool> _speakingController =
      StreamController<bool>.broadcast();

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
  int _speakingEpoch = 0;

  @override
  Stream<Map<String, dynamic>> get incomingJson => _jsonController.stream;

  @override
  Stream<Uint8List> get incomingAudio => _audioController.stream;

  @override
  Stream<String> get errors => _errorController.stream;

  @override
  Stream<bool> get speaking => _speakingController.stream;

  @override
  int get serverSampleRate => _transport?.serverSampleRate ?? -1;

  @override
  Future<bool> connect(TransportClient transport) async {
    await disconnect();
    _transport = transport;
    final connected = await _transport!.connect();
    if (!connected) {
      return false;
    }

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

    await _encodeSubscription?.cancel();
    await _decodeSubscription?.cancel();
    _encodeSubscription = null;
    _decodeSubscription = null;
    await _audioInput.stop();
    _audioOutput.dispose();
    _opusInputController?.close();
    _opusInputController = null;

    await _jsonSubscription?.cancel();
    await _audioSubscription?.cancel();
    await _errorSubscription?.cancel();
    _jsonSubscription = null;
    _audioSubscription = null;
    _errorSubscription = null;

    await _transport?.disconnect();
    _transport = null;
  }

  @override
  Future<void> startListening() async {
    if (_transport == null) {
      return;
    }
    if (_isListening) {
      _canSendAudio = true;
      return;
    }
    await _transport!.startListening(ListeningMode.autoStop);
    _startEncodingIfNeeded();
    _isListening = true;
    _canSendAudio = true;
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
  }

  void _startEncodingIfNeeded() {
    if (_encodeSubscription != null) {
      return;
    }
    final pcmStream = _audioInput.start();
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
            await _transport?.sendAudio(Uint8List.fromList(encoded));
          }
        });
  }

  void _handleIncomingJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
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

  void _handleIncomingAudio(Uint8List data) {
    _audioController.add(data);
    if (data.isEmpty || _opusInputController == null) {
      return;
    }
    _opusInputController!.add(Uint8List.fromList(data));
  }

  void _handleError(String error) {
    _canSendAudio = false;
    _isListening = false;
    _errorController.add(error);
  }

  Future<void> _handleSpeakingChanged(bool speaking) async {
    _speakingEpoch += 1;
    final epoch = _speakingEpoch;
    if (_isSpeaking == speaking) {
      return;
    }
    _isSpeaking = speaking;
    _speakingController.add(speaking);
    if (speaking) {
      await stopListening();
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
}
