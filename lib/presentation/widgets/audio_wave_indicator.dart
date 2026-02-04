import 'dart:math' as math;

import 'package:flutter/material.dart';

class AudioWaveIndicator extends StatefulWidget {
  const AudioWaveIndicator({super.key, required this.level, required this.color});

  final double level;
  final Color color;

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
  late final AnimationController _controller;
  late final List<double> _barSeeds = _buildSeeds();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 0,
    );
  }

  @override
  void didUpdateWidget(covariant AudioWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _animateToLevel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateToLevel() {
    final target = widget.level.clamp(0.0, 1.0);
    if (target == 0) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final level = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < AudioWaveIndicator._heights.length; i++) ...[
                Container(
                  width: 5,
                  height: _scaledHeight(
                    AudioWaveIndicator._heights[i],
                    i,
                    level,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (i != AudioWaveIndicator._heights.length - 1)
                  const SizedBox(width: 1),
              ],
            ],
          );
        },
      ),
    );
  }

  double _scaledHeight(double base, int index, double level) {
    final seed = _barSeeds[index % _barSeeds.length];
    final intensity = level.clamp(0.0, 1.0);
    final boosted = math.pow(intensity, 0.5).toDouble();
    final scaled = base * (0.2 + 1.2 * boosted * seed);
    return scaled.clamp(4.0, base * 1.4);
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
