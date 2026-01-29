import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';

// Ported from Android Kotlin: AudioRecorder.kt
class AudioRecorder {
  AudioRecorder(this._sampleRate, this._channels, this._frameSizeMs) {
    _frameSize = (_sampleRate * _frameSizeMs) ~/ 1000;
    _frameBytes = _frameSize * _channels * 2;
  }

  final int _sampleRate;
  final int _channels;
  final int _frameSizeMs;

  late final int _frameSize;
  late final int _frameBytes;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamController<Uint8List>? _pcmController;
  StreamController<Uint8List>? _rawController;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription? _rawSubscription;

  Stream<Uint8List> startRecording() {
    _pcmController ??= StreamController<Uint8List>.broadcast();
    _rawController ??= StreamController<Uint8List>();

    _rawSubscription ??= _rawController!.stream.listen((event) {
      _buffer.add(event);
      while (_buffer.length >= _frameBytes) {
        final combined = _buffer.takeBytes();
        final frame = Uint8List.sublistView(combined, 0, _frameBytes);
        _pcmController!.add(Uint8List.fromList(frame));
        final rest = Uint8List.sublistView(combined, _frameBytes);
        if (rest.isNotEmpty) {
          _buffer.add(rest);
        }
      }
    });

    _openAndStart();
    return _pcmController!.stream;
  }

  Future<void> _openAndStart() async {
    if (!_recorder.isRecording) {
      await _recorder.openRecorder();
      await _recorder.startRecorder(
        toStream: _rawController!.sink,
        codec: Codec.pcm16,
        numChannels: _channels,
        sampleRate: _sampleRate,
      );
    }
  }

  void stopRecording() {
    _recorder.stopRecorder();
    _recorder.closeRecorder();
    _rawSubscription?.cancel();
    _rawSubscription = null;
    _rawController?.close();
    _rawController = null;
    _pcmController?.close();
    _pcmController = null;
    _buffer.clear();
  }
}
