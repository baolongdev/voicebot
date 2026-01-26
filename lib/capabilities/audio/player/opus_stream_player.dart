import 'dart:async';
import 'dart:typed_data';

import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import '../../../core/logging/app_logger.dart';
import 'native_audio_track_player.dart';

// Ported from Android Kotlin: OpusStreamPlayer.kt
class OpusStreamPlayer {
  OpusStreamPlayer(this._sampleRate, this._channels, this._frameSizeMs);

  final int _sampleRate;
  final int _channels;
  // Kept for parity with Android constructor signature.
  // ignore: unused_field
  final int _frameSizeMs;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final NativeAudioTrackPlayer _nativePlayer = NativeAudioTrackPlayer();
  StreamSink<Uint8List>? _sink;
  StreamSubscription<Uint8List?>? _subscription;
  StreamSubscription<PlaybackDisposition>? _progressSubscription;
  bool _isPlaying = false;
  DateTime? _lastWriteAt;
  late final int _bytesPerSecond;
  late final int _drainMs;
  late final int _bufferSizeBytes;
  Duration _lastPosition = Duration.zero;
  DateTime? _lastPositionChangeAt;
  int _lastHeadPosition = 0;

  Future<void> start(Stream<Uint8List?> pcmStream) async {
    if (_isPlaying) {
      return;
    }
    _isPlaying = true;
    _bytesPerSecond = _sampleRate * _channels * 2;
    _bufferSizeBytes = 65536;
    _drainMs = (_bytesPerSecond > 0)
        ? (_bufferSizeBytes * 1000 / _bytesPerSecond).ceil() + 200
        : 200;
    if (Platform.isAndroid) {
      await _nativePlayer.init(
        sampleRate: _sampleRate,
        channels: _channels,
        bufferSize: _bufferSizeBytes,
      );
    } else {
      await _player.openPlayer();
      await _player.setSubscriptionDuration(const Duration(milliseconds: 50));
      await _player.startPlayerFromStream(
        codec: Codec.pcm16,
        numChannels: _channels,
        sampleRate: _sampleRate,
        interleaved: true,
        bufferSize: _bufferSizeBytes,
      );
      _sink = _player.uint8ListSink;

      _progressSubscription = _player.onProgress?.listen((event) {
        final position = event.position;
        if (position > _lastPosition) {
          _lastPosition = position;
          _lastPositionChangeAt = DateTime.now();
        }
      });
    }

    _subscription = pcmStream.listen((data) {
      if (data == null) {
        return;
      }
      try {
        _lastWriteAt = DateTime.now();
        if (Platform.isAndroid) {
          _nativePlayer.write(data);
        } else {
          _sink?.add(data);
        }
      } catch (_) {
        // ignore: avoid_print
        print('Error writing to AudioTrack');
      }
    });
  }

  void stop() {
    if (!_isPlaying) {
      return;
    }
    _isPlaying = false;
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _subscription?.cancel();
    _subscription = null;
    if (Platform.isAndroid) {
      _nativePlayer.stop();
    } else {
      _player.stopPlayer();
    }
  }

  void release() {
    stop();
    if (Platform.isAndroid) {
      _nativePlayer.release();
    } else {
      _player.closePlayer();
    }
  }

  Future<void> waitForPlaybackCompletion() async {
    const quietWindow = Duration(milliseconds: 300);
    final start = DateTime.now();
    const maxWait = Duration(seconds: 4);

    if (Platform.isAndroid) {
      var last = await _nativePlayer.getPlaybackHeadPosition();
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        final current = await _nativePlayer.getPlaybackHeadPosition();
        if (current != last) {
          last = current;
          _lastHeadPosition = current;
        } else {
          break;
        }
        if (DateTime.now().difference(start) > maxWait) {
          AppLogger.log('OpusStreamPlayer', 'head position wait timeout');
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return;
    }

    if (_lastPositionChangeAt != null) {
      while (DateTime.now().difference(_lastPositionChangeAt!) < quietWindow) {
        if (DateTime.now().difference(start) > maxWait) {
          AppLogger.log('OpusStreamPlayer', 'progress wait timeout, fallback');
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return;
    }

    if (_lastWriteAt == null) {
      return;
    }
    while (DateTime.now().difference(_lastWriteAt!) < quietWindow) {
      if (DateTime.now().difference(start) > maxWait) {
        AppLogger.log('OpusStreamPlayer', 'write wait timeout, fallback');
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    AppLogger.log('OpusStreamPlayer', 'drain buffer for ${_drainMs}ms');
    await Future<void>.delayed(Duration(milliseconds: _drainMs));
  }
}
