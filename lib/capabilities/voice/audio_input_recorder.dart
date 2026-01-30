import 'dart:typed_data';

import '../../core/audio/audio_config.dart';
import '../audio/recorder/audio_recorder.dart';
import 'audio_input.dart';

class RecorderAudioInput implements AudioInput {
  RecorderAudioInput({
    int? sampleRate,
    int? channels,
    int? frameDurationMs,
  })  : _sampleRate = sampleRate ?? AudioConfig.sampleRate,
        _channels = channels ?? AudioConfig.channels,
        _frameDurationMs = frameDurationMs ?? AudioConfig.frameDurationMs,
        _recorder = AudioRecorder(
          sampleRate ?? AudioConfig.sampleRate,
          channels ?? AudioConfig.channels,
          frameDurationMs ?? AudioConfig.frameDurationMs,
        );

  final int _sampleRate;
  final int _channels;
  final int _frameDurationMs;
  final AudioRecorder _recorder;

  @override
  int get sampleRate => _sampleRate;

  @override
  int get channels => _channels;

  @override
  int get frameDurationMs => _frameDurationMs;

  @override
  Stream<Uint8List> start() => _recorder.startRecording();

  @override
  Future<void> stop() async {
    _recorder.stopRecording();
  }
}
