import 'dart:async';
import 'dart:typed_data';

import '../audio/player/opus_stream_player.dart';
import 'audio_output.dart';

class PlayerAudioOutput implements AudioOutput {
  OpusStreamPlayer? _player;
  StreamController<Uint8List?>? _pcmController;
  bool _started = false;

  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int frameDurationMs,
  }) async {
    if (_started) {
      dispose();
    }
    _started = true;
    _pcmController = StreamController<Uint8List?>.broadcast();
    _player = OpusStreamPlayer(sampleRate, channels, frameDurationMs);
    await _player!.start(_pcmController!.stream);
  }

  @override
  void enqueue(Uint8List pcm) {
    _pcmController?.add(pcm);
  }

  @override
  void resetBuffer() {
    _player?.resetBuffer();
  }

  @override
  Future<void> flushBufferedPlayback() async {
    await _player?.flushBufferedPlayback();
  }

  @override
  Future<void> waitForPlaybackCompletion() async {
    await _player?.waitForPlaybackCompletion();
  }

  @override
  void stop() {
    _pcmController?.close();
    _pcmController = null;
    _player?.stop();
    _started = false;
  }

  @override
  void dispose() {
    _pcmController?.close();
    _pcmController = null;
    _player?.release();
    _player = null;
    _started = false;
  }
}
