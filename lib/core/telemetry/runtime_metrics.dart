import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';

import '../logging/app_logger.dart';

class RuntimeMetrics {
  RuntimeMetrics._();

  static final RuntimeMetrics instance = RuntimeMetrics._();

  final Map<String, int> _counters = <String, int>{};
  final List<int> _gcPauseSamplesMs = <int>[];
  final List<double> _frameTotalSamplesMs = <double>[];
  final Stopwatch _uptime = Stopwatch()..start();

  Timer? _flushTimer;
  bool _autoFlushStarted = false;
  int _frameCount = 0;
  int _jankyFrameCount = 0;
  int _estimatedDroppedFrames = 0;
  static final RegExp _androidGcPauseRegex = RegExp(
    r'paused\s+(\d+)us,([\d.]+)ms total',
  );

  void startAutoFlush({Duration interval = const Duration(seconds: 30)}) {
    if (_autoFlushStarted) {
      return;
    }
    _autoFlushStarted = true;
    _flushTimer = Timer.periodic(interval, (_) => flushSnapshot());
  }

  void stopAutoFlush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _autoFlushStarted = false;
  }

  void incrementCounter(String key, {int delta = 1}) {
    _counters[key] = (_counters[key] ?? 0) + delta;
  }

  void incrementRecorderRestartCount() {
    incrementCounter('recorder_restart_count');
  }

  void incrementChimePlaybackCount() {
    incrementCounter('chime_playback_count');
  }

  void incrementCameraFrameDropCount() {
    incrementCounter('camera_frame_drop_count');
  }

  void incrementMemoryPressureCount() {
    incrementCounter('memory_pressure_count');
  }

  void recordAudioTransition({
    required String from,
    required String to,
    required String reason,
  }) {
    incrementCounter('audio_transition_count');
    AppLogger.event(
      'RuntimeMetrics',
      'audio_transition',
      fields: <String, Object?>{'from': from, 'to': to, 'reason': reason},
      level: 'D',
    );
  }

  void observeGcPauseMs(int milliseconds) {
    if (milliseconds <= 0) {
      return;
    }
    _gcPauseSamplesMs.add(milliseconds);
    if (_gcPauseSamplesMs.length > 512) {
      _gcPauseSamplesMs.removeRange(0, _gcPauseSamplesMs.length - 512);
    }
  }

  void observeAndroidGcLogLine(String line) {
    final match = _androidGcPauseRegex.firstMatch(line);
    if (match == null) {
      return;
    }
    final msValue = double.tryParse(match.group(2) ?? '');
    if (msValue == null || !msValue.isFinite) {
      return;
    }
    observeGcPauseMs(msValue.round());
  }

  void observeFrameTiming(FrameTiming timing) {
    final totalMs = timing.totalSpan.inMicroseconds / 1000.0;
    _frameTotalSamplesMs.add(totalMs);
    if (_frameTotalSamplesMs.length > 512) {
      _frameTotalSamplesMs.removeRange(0, _frameTotalSamplesMs.length - 512);
    }
    _frameCount += 1;
    final dropped = math.max(0, (totalMs / 16.67).ceil() - 1);
    _estimatedDroppedFrames += dropped;
    if (totalMs > 16.67) {
      _jankyFrameCount += 1;
    }
  }

  void flushSnapshot() {
    final uptimeSec = (_uptime.elapsedMilliseconds / 1000).toStringAsFixed(1);
    final frameDropRate = _frameCount <= 0
        ? 0.0
        : (_estimatedDroppedFrames / _frameCount);
    final jankRate = _frameCount <= 0 ? 0.0 : (_jankyFrameCount / _frameCount);
    final cameraDropCount = _counters['camera_frame_drop_count'] ?? 0;
    final droppedImageBufferRate = _frameCount <= 0
        ? 0.0
        : (cameraDropCount / _frameCount);
    final gcP50 = _percentileInt(_gcPauseSamplesMs, 50);
    final gcP95 = _percentileInt(_gcPauseSamplesMs, 95);
    final frameP95 = _percentileDouble(_frameTotalSamplesMs, 95);

    AppLogger.event(
      'RuntimeMetrics',
      'snapshot',
      fields: <String, Object?>{
        'uptime_s': uptimeSec,
        'audio_transition_count': _counters['audio_transition_count'] ?? 0,
        'recorder_restart_count': _counters['recorder_restart_count'] ?? 0,
        'camera_frame_drop_count': cameraDropCount,
        'dropped_image_buffer_rate': droppedImageBufferRate.toStringAsFixed(4),
        'chime_playback_count': _counters['chime_playback_count'] ?? 0,
        'memory_pressure_count': _counters['memory_pressure_count'] ?? 0,
        'frame_count': _frameCount,
        'jank_rate': jankRate.toStringAsFixed(4),
        'frame_drop_rate': frameDropRate.toStringAsFixed(4),
        'frame_total_ms_p95': frameP95.toStringAsFixed(2),
        'gc_pause_ms_p50': gcP50,
        'gc_pause_ms_p95': gcP95,
      },
      level: 'I',
    );
  }

  int _percentileInt(List<int> values, int percentile) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = List<int>.from(values)..sort();
    final rank = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[rank.clamp(0, sorted.length - 1)];
  }

  double _percentileDouble(List<double> values, int percentile) {
    if (values.isEmpty) {
      return 0;
    }
    final sorted = List<double>.from(values)..sort();
    final rank = ((percentile / 100) * (sorted.length - 1)).round();
    return sorted[rank.clamp(0, sorted.length - 1)];
  }
}
