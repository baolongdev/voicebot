import 'dart:typed_data';

abstract class AudioOutput {
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int frameDurationMs,
  });
  void enqueue(Uint8List pcm);
  void resetBuffer();
  Future<void> flushBufferedPlayback();
  Future<void> waitForPlaybackCompletion();
  void stop();
  void dispose();
}
