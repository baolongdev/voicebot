import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart' as record;
import '../../../core/logging/app_logger.dart';
import '../../../core/telemetry/runtime_metrics.dart';

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
  record.AudioRecorder? _windowsRecorder;
  StreamController<Uint8List>? _pcmController;
  StreamController<Uint8List>? _rawController;
  final BytesBuilder _buffer = BytesBuilder(copy: false);
  StreamSubscription? _rawSubscription;
  StreamSubscription<Uint8List>? _windowsSubscription;
  bool _isOpen = false;
  bool _opening = false;

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

    unawaited(_openAndStart());
    return _pcmController!.stream;
  }

  Future<void> _openAndStart() async {
    if (_opening) {
      return;
    }
    _opening = true;
    try {
      if (Platform.isWindows) {
        if (_windowsSubscription != null) {
          return;
        }
        try {
          _windowsRecorder ??= record.AudioRecorder();
          final hasPermission = await _windowsRecorder!.hasPermission();
          if (!hasPermission) {
            AppLogger.log('AudioRecorder', 'mic permission not granted');
            return;
          }
          RuntimeMetrics.instance.incrementRecorderRestartCount();
          final stream = await _windowsRecorder!.startStream(
            record.RecordConfig(
              encoder: record.AudioEncoder.pcm16bits,
              sampleRate: _sampleRate,
              numChannels: _channels,
            ),
          );
          _windowsSubscription = stream.listen((data) {
            _rawController?.add(data);
          });
        } on MissingPluginException {
          AppLogger.log(
            'AudioRecorder',
            'record plugin not registered; skipping recorder init',
          );
        }
        return;
      }

      try {
        if (!_isOpen) {
          await _recorder.openRecorder();
          _isOpen = true;
        }
        if (!_recorder.isRecording) {
          RuntimeMetrics.instance.incrementRecorderRestartCount();
          await _recorder.startRecorder(
            toStream: _rawController!.sink,
            codec: Codec.pcm16,
            numChannels: _channels,
            sampleRate: _sampleRate,
          );
        }
      } on MissingPluginException {
        AppLogger.log(
          'AudioRecorder',
          'flutter_sound plugin not registered; skipping recorder init',
        );
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> stopRecording() async {
    if (!Platform.isWindows) {
      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
      } catch (_) {}
    }
    await _rawSubscription?.cancel();
    _rawSubscription = null;
    await _windowsSubscription?.cancel();
    _windowsSubscription = null;
    if (Platform.isWindows) {
      try {
        await _windowsRecorder?.stop();
      } catch (_) {}
    }
    await _rawController?.close();
    _rawController = null;
    await _pcmController?.close();
    _pcmController = null;
    _buffer.clear();
  }

  Future<void> dispose() async {
    await stopRecording();
    if (Platform.isWindows) {
      await _windowsRecorder?.dispose();
      _windowsRecorder = null;
      return;
    }
    if (_isOpen) {
      try {
        await _recorder.closeRecorder();
      } catch (_) {}
      _isOpen = false;
    }
  }
}
