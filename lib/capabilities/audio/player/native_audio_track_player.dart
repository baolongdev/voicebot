import 'package:flutter/services.dart';

class NativeAudioTrackPlayer {
  NativeAudioTrackPlayer({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('voicebot/audio_player');

  final MethodChannel _channel;
  bool _initialized = false;

  Future<void> init({
    required int sampleRate,
    required int channels,
    required int bufferSize,
  }) async {
    await _channel.invokeMethod<void>(
      'init',
      <String, dynamic>{
        'sampleRate': sampleRate,
        'channels': channels,
        'bufferSize': bufferSize,
      },
    );
    _initialized = true;
  }

  Future<void> write(Uint8List data) async {
    if (!_initialized) {
      return;
    }
    await _channel.invokeMethod<void>('write', data);
  }

  Future<int> getPlaybackHeadPosition() async {
    if (!_initialized) {
      return 0;
    }
    final result = await _channel.invokeMethod<int>('getPlaybackHeadPosition');
    return result ?? 0;
  }

  Future<void> stop() async {
    if (!_initialized) {
      return;
    }
    await _channel.invokeMethod<void>('stop');
  }

  Future<void> release() async {
    if (!_initialized) {
      return;
    }
    await _channel.invokeMethod<void>('release');
    _initialized = false;
  }
}
