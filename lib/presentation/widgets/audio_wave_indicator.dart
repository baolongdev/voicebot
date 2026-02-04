import 'dart:math' as math;

import 'package:flutter/material.dart';

class AudioWaveIndicator extends StatefulWidget {
  const AudioWaveIndicator({
    super.key,
    required this.level,
    required this.color,
    this.idle = false,
  });

  final double level;
  final Color color;
  final bool idle;

  static const _heights = [
    8.0,
    10.0,
    12.0,
    14.0,
    16.0,
    18.0,
    20.0,
    22.0,
    24.0,
    26.0,
    28.0,
    30.0,
    32.0,
    34.0,
    36.0,
    38.0,
    40.0,
    42.0,
    44.0,
    46.0,
    48.0,
    46.0,
    44.0,
    42.0,
    40.0,
    38.0,
    36.0,
    34.0,
    32.0,
    30.0,
    28.0,
    26.0,
    24.0,
    22.0,
    20.0,
    18.0,
    16.0,
    14.0,
    12.0,
    10.0,
    8.0,
  ];

  @override
  State<AudioWaveIndicator> createState() => _AudioWaveIndicatorState();
}

class _AudioWaveIndicatorState extends State<AudioWaveIndicator>
    with SingleTickerProviderStateMixin {
  static const double _minDelta = 0.02;
  late final AnimationController _controller;
  late final List<double> _barSeeds = _buildSeeds();
  bool _idleMode = false;
  bool _disableAnimations = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 0,
    );
    _syncAnimation(force: true);
  }

  @override
  void didUpdateWidget(covariant AudioWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    final levelChanged =
        (oldWidget.level - widget.level).abs() > _minDelta;
    final idleChanged = oldWidget.idle != widget.idle;
    if (levelChanged || idleChanged) {
      _syncAnimation();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mediaQuery = MediaQuery.maybeOf(context);
    final disableAnimations = mediaQuery?.disableAnimations ?? false;
    if (_disableAnimations != disableAnimations) {
      _disableAnimations = disableAnimations;
      _syncAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _syncAnimation({bool force = false}) {
    final target = widget.level.clamp(0.0, 1.0);
    final idleRequested =
        widget.idle && target <= 0.001 && !_disableAnimations;
    if (idleRequested) {
      _idleMode = true;
      if (force || !_controller.isAnimating) {
        _controller
          ..duration = const Duration(milliseconds: 1400)
          ..repeat();
      }
      return;
    }

    _idleMode = false;
    _controller.stop();
    if (target == 0) {
      _controller.value = 0;
      return;
    }
    _controller.duration = const Duration(milliseconds: 160);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _AudioWavePainter(
            color: widget.color,
            seeds: _barSeeds,
            heights: AudioWaveIndicator._heights,
            animation: _controller,
            idle: _idleMode,
          ),
        ),
      ),
    );
  }

  List<double> _buildSeeds() {
    final seeds = <double>[];
    for (var i = 0; i < AudioWaveIndicator._heights.length; i++) {
      final v = math.sin(i * 12.9898) * 43758.5453;
      final seed = v - v.floorToDouble();
      seeds.add(0.6 + 0.4 * seed);
    }
    return seeds;
  }
}

class _AudioWavePainter extends CustomPainter {
  _AudioWavePainter({
    required this.color,
    required this.seeds,
    required this.heights,
    required this.animation,
    required this.idle,
  }) : super(repaint: animation);

  final Color color;
  final List<double> seeds;
  final List<double> heights;
  final Animation<double> animation;
  final bool idle;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final level = animation.value.clamp(0.0, 1.0);
    final phase = level * math.pi * 2;
    final count = heights.length;
    var gap = 2.0;
    var barWidth = (size.width - gap * (count - 1)) / count;
    if (barWidth < 2.5) {
      gap = 1.0;
      barWidth = (size.width - gap * (count - 1)) / count;
    }
    barWidth = math.max(1.5, barWidth);
    final totalWidth = count * barWidth + (count - 1) * gap;
    final startX = (size.width - totalWidth) / 2;
    final centerY = size.height / 2;
    for (var i = 0; i < count; i++) {
      final base = heights[i];
      final seed = seeds[i % seeds.length];
      final drive = idle
          ? (0.22 + 0.12 * math.sin(phase + i * 0.45))
          : math.pow(level, 0.5).toDouble();
      final scaled = (base * 1.35 * (0.2 + 1.2 * drive * seed))
          .clamp(6.0, base * 1.8);
      final x = startX + i * (barWidth + gap);
      final rect = Rect.fromCenter(
        center: Offset(x + barWidth / 2, centerY),
        width: barWidth,
        height: scaled,
      );
      final radius = Radius.circular(barWidth);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AudioWavePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.heights.length != heights.length ||
        oldDelegate.seeds.length != seeds.length;
  }
}
