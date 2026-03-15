import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_colors.dart';

@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.headerBackground,
    required this.headerForeground,
    required this.homeSurface,
    required this.homeAccent,
    required this.accentForeground,
    required this.emotionBackground,
    required this.emotionBorder,
    required this.emotionTones,
  });

  final Color headerBackground;
  final Color headerForeground;
  final Color homeSurface;
  final Color homeAccent;
  final Color accentForeground;
  final Color emotionBackground;
  final Color emotionBorder;
  final Map<String, EmotionTone> emotionTones;

  static final BrandColors light = fromPalette(
    AppColors.light,
    brightness: Brightness.light,
  );

  static final BrandColors dark = fromPalette(
    AppColors.dark,
    brightness: Brightness.dark,
  );

  static BrandColors fromPalette(
    AppSemanticColors palette, {
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    return BrandColors(
      headerBackground: palette.primary,
      headerForeground: palette.onPrimary,
      homeSurface: palette.surface,
      homeAccent: palette.primaryAlt,
      accentForeground: palette.onPrimary,
      emotionBackground: palette.surface,
      emotionBorder: palette.outline,
      emotionTones: _buildEmotionTones(palette, isDark),
    );
  }

  static Map<String, EmotionTone> _buildEmotionTones(
    AppSemanticColors palette,
    bool isDark,
  ) {
    final baseHsl = HSLColor.fromColor(palette.primary);
    return Map<String, EmotionTone>.unmodifiable({
      for (final entry in _emotionToneSeeds.entries)
        entry.key: _buildToneFromSeed(
          palette: palette,
          baseHsl: baseHsl,
          seed: entry.value,
          isDark: isDark,
        ),
    });
  }

  static EmotionTone _buildToneFromSeed({
    required AppSemanticColors palette,
    required HSLColor baseHsl,
    required _EmotionToneSeed seed,
    required bool isDark,
  }) {
    final hue = ((baseHsl.hue + seed.hueShift) % 360 + 360) % 360;
    final background = HSLColor.fromAHSL(
      1,
      hue,
      seed.saturation.clamp(0.0, 1.0),
      isDark ? seed.darkLightness : seed.lightLightness,
    ).toColor();
    final foreground = _resolveForeground(
      palette: palette,
      background: background,
      isDark: isDark,
    );
    return EmotionTone(background, foreground);
  }

  static Color _resolveForeground({
    required AppSemanticColors palette,
    required Color background,
    required bool isDark,
  }) {
    final preferred = isDark ? palette.onSurface : palette.onBackground;
    if (_contrastRatio(background, preferred) >= 4.5) {
      return preferred;
    }
    final white = _contrastRatio(background, Colors.white);
    final black = _contrastRatio(background, Colors.black);
    return white >= black ? Colors.white : Colors.black;
  }

  static double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final bright = math.max(l1, l2);
    final dark = math.min(l1, l2);
    return (bright + 0.05) / (dark + 0.05);
  }

  @override
  BrandColors copyWith({
    Color? headerBackground,
    Color? headerForeground,
    Color? homeSurface,
    Color? homeAccent,
    Color? accentForeground,
    Color? emotionBackground,
    Color? emotionBorder,
    Map<String, EmotionTone>? emotionTones,
  }) {
    return BrandColors(
      headerBackground: headerBackground ?? this.headerBackground,
      headerForeground: headerForeground ?? this.headerForeground,
      homeSurface: homeSurface ?? this.homeSurface,
      homeAccent: homeAccent ?? this.homeAccent,
      accentForeground: accentForeground ?? this.accentForeground,
      emotionBackground: emotionBackground ?? this.emotionBackground,
      emotionBorder: emotionBorder ?? this.emotionBorder,
      emotionTones: emotionTones ?? this.emotionTones,
    );
  }

  @override
  BrandColors lerp(ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) {
      return this;
    }
    return BrandColors(
      headerBackground: Color.lerp(
        headerBackground,
        other.headerBackground,
        t,
      )!,
      headerForeground: Color.lerp(
        headerForeground,
        other.headerForeground,
        t,
      )!,
      homeSurface: Color.lerp(homeSurface, other.homeSurface, t)!,
      homeAccent: Color.lerp(homeAccent, other.homeAccent, t)!,
      accentForeground: Color.lerp(
        accentForeground,
        other.accentForeground,
        t,
      )!,
      emotionBackground: Color.lerp(
        emotionBackground,
        other.emotionBackground,
        t,
      )!,
      emotionBorder: Color.lerp(emotionBorder, other.emotionBorder, t)!,
      emotionTones: t < 0.5 ? emotionTones : other.emotionTones,
    );
  }
}

@immutable
class EmotionTone {
  const EmotionTone(this.background, this.foreground);

  final Color background;
  final Color foreground;
}

class _EmotionToneSeed {
  const _EmotionToneSeed({
    required this.hueShift,
    required this.saturation,
    required this.lightLightness,
    required this.darkLightness,
  });

  final double hueShift;
  final double saturation;
  final double lightLightness;
  final double darkLightness;
}

const Map<String, _EmotionToneSeed> _emotionToneSeeds = {
  'neutral': _EmotionToneSeed(
    hueShift: 0,
    saturation: 0.14,
    lightLightness: 0.86,
    darkLightness: 0.33,
  ),
  'happy': _EmotionToneSeed(
    hueShift: 32,
    saturation: 0.64,
    lightLightness: 0.83,
    darkLightness: 0.37,
  ),
  'laughing': _EmotionToneSeed(
    hueShift: 24,
    saturation: 0.68,
    lightLightness: 0.82,
    darkLightness: 0.36,
  ),
  'funny': _EmotionToneSeed(
    hueShift: -18,
    saturation: 0.54,
    lightLightness: 0.84,
    darkLightness: 0.36,
  ),
  'silly': _EmotionToneSeed(
    hueShift: 58,
    saturation: 0.55,
    lightLightness: 0.84,
    darkLightness: 0.36,
  ),
  'confident': _EmotionToneSeed(
    hueShift: -42,
    saturation: 0.5,
    lightLightness: 0.82,
    darkLightness: 0.35,
  ),
  'loving': _EmotionToneSeed(
    hueShift: -28,
    saturation: 0.6,
    lightLightness: 0.83,
    darkLightness: 0.35,
  ),
  'kissy': _EmotionToneSeed(
    hueShift: -34,
    saturation: 0.62,
    lightLightness: 0.82,
    darkLightness: 0.35,
  ),
  'embarrassed': _EmotionToneSeed(
    hueShift: 12,
    saturation: 0.5,
    lightLightness: 0.83,
    darkLightness: 0.35,
  ),
  'winking': _EmotionToneSeed(
    hueShift: 44,
    saturation: 0.6,
    lightLightness: 0.83,
    darkLightness: 0.36,
  ),
  'sad': _EmotionToneSeed(
    hueShift: 180,
    saturation: 0.45,
    lightLightness: 0.84,
    darkLightness: 0.34,
  ),
  'crying': _EmotionToneSeed(
    hueShift: 192,
    saturation: 0.48,
    lightLightness: 0.82,
    darkLightness: 0.33,
  ),
  'sleepy': _EmotionToneSeed(
    hueShift: 210,
    saturation: 0.28,
    lightLightness: 0.85,
    darkLightness: 0.33,
  ),
  'angry': _EmotionToneSeed(
    hueShift: -70,
    saturation: 0.62,
    lightLightness: 0.82,
    darkLightness: 0.34,
  ),
  'surprised': _EmotionToneSeed(
    hueShift: 36,
    saturation: 0.58,
    lightLightness: 0.84,
    darkLightness: 0.36,
  ),
  'shocked': _EmotionToneSeed(
    hueShift: 22,
    saturation: 0.62,
    lightLightness: 0.83,
    darkLightness: 0.35,
  ),
  'thinking': _EmotionToneSeed(
    hueShift: 145,
    saturation: 0.42,
    lightLightness: 0.84,
    darkLightness: 0.34,
  ),
  'relaxed': _EmotionToneSeed(
    hueShift: 120,
    saturation: 0.4,
    lightLightness: 0.84,
    darkLightness: 0.35,
  ),
  'cool': _EmotionToneSeed(
    hueShift: 165,
    saturation: 0.5,
    lightLightness: 0.83,
    darkLightness: 0.34,
  ),
  'delicious': _EmotionToneSeed(
    hueShift: 18,
    saturation: 0.58,
    lightLightness: 0.83,
    darkLightness: 0.35,
  ),
  'confused': _EmotionToneSeed(
    hueShift: -56,
    saturation: 0.24,
    lightLightness: 0.84,
    darkLightness: 0.33,
  ),
};
