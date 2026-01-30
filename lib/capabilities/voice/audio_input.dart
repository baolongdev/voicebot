import 'dart:typed_data';

abstract class AudioInput {
  int get sampleRate;
  int get channels;
  int get frameDurationMs;

  Stream<Uint8List> start();
  Future<void> stop();
}
