import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../theme/brand_colors.dart';
import '../../../theme/theme_extensions.dart';

class EmotionPalette {
  const EmotionPalette({
    required this.surface,
    required this.accent,
    required this.accentForeground,
  });

  final Color surface;
  final Color accent;
  final Color accentForeground;

  static EmotionPalette resolve(BuildContext context, String? emotion) {
    final brand = context.theme.brand;
    final normalized = emotion?.toLowerCase().trim();
    final tone = _toneFor(normalized, brand);
    return EmotionPalette(
      surface: brand.homeSurface,
      accent: tone.background,
      accentForeground: tone.foreground,
    );
  }

  Color controlBackground(BuildContext context) {
    return surface;
  }

  Color controlBorder(BuildContext context) {
    return context.theme.brand.emotionBorder;
  }

  Color controlForeground(BuildContext context) {
    return context.theme.brand.headerForeground;
  }

  static _EmotionTone _toneFor(String? emotion, BrandColors brand) {
    final tone = brand.emotionTones[emotion];
    if (tone != null) {
      return _EmotionTone(tone.background, tone.foreground);
    }
    return _EmotionTone(brand.homeAccent, brand.accentForeground);
  }
}

class _EmotionTone {
  _EmotionTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}
