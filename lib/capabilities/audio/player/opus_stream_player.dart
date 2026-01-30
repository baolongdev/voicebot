import 'dart:async';
import 'dart:typed_data';

import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
  AudioPlayer? _windowsPlayer;
  final BytesBuilder _windowsBuffer = BytesBuilder(copy: false);
  StreamSubscription<void>? _windowsPlayerCompleteSub;
  final List<String> _windowsQueue = <String>[];
  bool _windowsPlaying = false;
  int _windowsChunkBytes = 0;
  bool _useFlutterSoundOnWindows = false;
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
    } else if (Platform.isWindows) {
      try {
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
        _useFlutterSoundOnWindows = true;
        AppLogger.log('OpusStreamPlayer', 'windows using flutter_sound stream');
        _progressSubscription = _player.onProgress?.listen((event) {
          final position = event.position;
          if (position > _lastPosition) {
            _lastPosition = position;
            _lastPositionChangeAt = DateTime.now();
          }
        });
      } on MissingPluginException {
        _useFlutterSoundOnWindows = false;
      } catch (_) {
        _useFlutterSoundOnWindows = false;
      }
      if (!_useFlutterSoundOnWindows) {
        try {
          _windowsPlayer = AudioPlayer();
          await _windowsPlayer!.setVolume(1.0);
          _windowsChunkBytes = (_bytesPerSecond * 180 / 1000).ceil();
          AppLogger.log('OpusStreamPlayer', 'windows using wav chunk playback');
        } on MissingPluginException {
          AppLogger.log(
            'OpusStreamPlayer',
            'audioplayers plugin not registered; skipping playback init',
          );
          _isPlaying = false;
          return;
        }
      }
    } else {
      try {
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
      } on MissingPluginException {
        AppLogger.log(
          'OpusStreamPlayer',
          'flutter_sound plugin not registered; skipping playback init',
        );
        _isPlaying = false;
        return;
      }
    }

    _subscription = pcmStream.listen((data) {
      if (data == null) {
        return;
      }
      try {
        _lastWriteAt = DateTime.now();
        if (Platform.isAndroid) {
          _nativePlayer.write(data);
        } else if (Platform.isWindows) {
          if (_useFlutterSoundOnWindows) {
            _sink?.add(data);
          } else {
            _windowsBuffer.add(data);
            _enqueueWindowsChunks(force: false);
          }
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
    } else if (Platform.isWindows) {
      if (_useFlutterSoundOnWindows) {
        _player.stopPlayer();
      } else {
        _windowsPlayer?.stop();
        _windowsPlayerCompleteSub?.cancel();
        _windowsPlayerCompleteSub = null;
        _windowsBuffer.clear();
        _windowsQueue.clear();
        _windowsPlaying = false;
      }
    } else {
      _player.stopPlayer();
    }
  }

  void release() {
    stop();
    if (Platform.isAndroid) {
      _nativePlayer.release();
    } else if (Platform.isWindows) {
      if (_useFlutterSoundOnWindows) {
        _player.closePlayer();
      } else {
        _windowsPlayer?.dispose();
        _windowsPlayer = null;
        _windowsPlayerCompleteSub?.cancel();
        _windowsPlayerCompleteSub = null;
        _windowsBuffer.clear();
        _windowsQueue.clear();
        _windowsPlaying = false;
      }
    } else {
      _player.closePlayer();
    }
  }

  void resetBuffer() {
    if (Platform.isWindows) {
      if (_useFlutterSoundOnWindows) {
        return;
      }
      _windowsBuffer.clear();
      _windowsQueue.clear();
      _windowsPlaying = false;
      _windowsPlayer?.stop();
    }
  }

  Future<void> flushBufferedPlayback() async {
    if (!Platform.isWindows) {
      return;
    }
    if (_useFlutterSoundOnWindows) {
      return;
    }
    if (_windowsPlayer == null) {
      AppLogger.log('OpusStreamPlayer', 'no windows player');
      return;
    }
    _enqueueWindowsChunks(force: true);
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

    if (Platform.isWindows && !_useFlutterSoundOnWindows) {
      while (true) {
        if (!_windowsPlaying &&
            _windowsQueue.isEmpty &&
            _windowsBuffer.isEmpty) {
          break;
        }
        if (DateTime.now().difference(start) > maxWait) {
          AppLogger.log('OpusStreamPlayer', 'playback wait timeout, fallback');
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
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

  Future<void> _enqueueWindowsChunks({required bool force}) async {
    if (_windowsPlayer == null) {
      return;
    }
    if (_windowsBuffer.isEmpty) {
      _playNextWindowsChunk();
      return;
    }
    final data = _windowsBuffer.takeBytes();
    _windowsBuffer.clear();
    if (!force && data.length < _windowsChunkBytes) {
      _windowsBuffer.add(data);
      return;
    }

    var offset = 0;
    while (offset < data.length) {
      var chunkSize = _windowsChunkBytes;
      if (chunkSize <= 0) {
        chunkSize = data.length;
      }
      if (!force && data.length - offset < chunkSize) {
        _windowsBuffer.add(Uint8List.sublistView(data, offset));
        break;
      }
      if (data.length - offset < chunkSize) {
        chunkSize = data.length - offset;
      }
      final chunk = Uint8List.sublistView(data, offset, offset + chunkSize);
      offset += chunkSize;
      final filePath = await _writeWavChunk(chunk);
      _windowsQueue.add(filePath);
    }
    _playNextWindowsChunk();
  }

  Future<String> _writeWavChunk(Uint8List data) async {
    final dir = await getTemporaryDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final filePath =
        '${dir.path}${Platform.pathSeparator}voicebot_playback_$ts.wav';
    final header = _buildWavHeaderWithLength(
      sampleRate: _sampleRate,
      channels: _channels,
      bitsPerSample: 16,
      dataLength: data.length,
    );
    final file = File(filePath);
    await file.writeAsBytes(<int>[...header, ...data], flush: true);
    return filePath;
  }

  void _playNextWindowsChunk() {
    if (_windowsPlayer == null || _windowsPlaying || _windowsQueue.isEmpty) {
      return;
    }
    final filePath = _windowsQueue.removeAt(0);
    _windowsPlaying = true;
    _windowsPlayerCompleteSub?.cancel();
    _windowsPlayerCompleteSub = _windowsPlayer!.onPlayerComplete.listen((_) {
      try {
        File(filePath).deleteSync();
      } catch (_) {
        // ignore: avoid_print
      }
      _windowsPlaying = false;
      _playNextWindowsChunk();
    });
    _windowsPlayer!.play(DeviceFileSource(filePath));
  }
}

Uint8List _buildWavHeader({
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
}) {
  const int headerSize = 44;
  const int unknownDataSize = 0xFFFFFFFF;
  final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final int blockAlign = channels * (bitsPerSample ~/ 8);
  final int riffChunkSize = 36 + unknownDataSize;

  final buffer = Uint8List(headerSize);
  final bytes = ByteData.view(buffer.buffer);

  buffer.setAll(0, 'RIFF'.codeUnits);
  bytes.setUint32(4, riffChunkSize, Endian.little);
  buffer.setAll(8, 'WAVE'.codeUnits);

  buffer.setAll(12, 'fmt '.codeUnits);
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, byteRate, Endian.little);
  bytes.setUint16(32, blockAlign, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);

  buffer.setAll(36, 'data'.codeUnits);
  bytes.setUint32(40, unknownDataSize, Endian.little);

  return buffer;
}

Uint8List _buildWavHeaderWithLength({
  required int sampleRate,
  required int channels,
  required int bitsPerSample,
  required int dataLength,
}) {
  const int headerSize = 44;
  final int byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final int blockAlign = channels * (bitsPerSample ~/ 8);
  final int riffChunkSize = 36 + dataLength;

  final buffer = Uint8List(headerSize);
  final bytes = ByteData.view(buffer.buffer);

  buffer.setAll(0, 'RIFF'.codeUnits);
  bytes.setUint32(4, riffChunkSize, Endian.little);
  buffer.setAll(8, 'WAVE'.codeUnits);

  buffer.setAll(12, 'fmt '.codeUnits);
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, channels, Endian.little);
  bytes.setUint32(24, sampleRate, Endian.little);
  bytes.setUint32(28, byteRate, Endian.little);
  bytes.setUint16(32, blockAlign, Endian.little);
  bytes.setUint16(34, bitsPerSample, Endian.little);

  buffer.setAll(36, 'data'.codeUnits);
  bytes.setUint32(40, dataLength, Endian.little);

  return buffer;
}

int _pcm16Peak(Uint8List data) {
  if (data.length < 2) {
    return 0;
  }
  var peak = 0;
  for (var i = 0; i + 1 < data.length; i += 2) {
    final sample = (data[i] | (data[i + 1] << 8));
    final signed = sample >= 0x8000 ? sample - 0x10000 : sample;
    final abs = signed.abs();
    if (abs > peak) {
      peak = abs;
    }
  }
  return peak;
}
