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

  static final BrandColors light = fromPalette(AppColors.light);

  static final BrandColors dark = fromPalette(AppColors.dark);

  static BrandColors fromPalette(AppSemanticColors palette) {
    return BrandColors(
      headerBackground: palette.primary,
      headerForeground: palette.onPrimary,
      homeSurface: palette.surface,
      homeAccent: palette.primaryAlt,
      accentForeground: palette.onPrimary,
      emotionBackground: palette.surface,
      emotionBorder: palette.outline,
      emotionTones: _emotionTonesLight,
    );
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
      headerBackground: Color.lerp(headerBackground, other.headerBackground, t)!,
      headerForeground: Color.lerp(headerForeground, other.headerForeground, t)!,
      homeSurface: Color.lerp(homeSurface, other.homeSurface, t)!,
      homeAccent: Color.lerp(homeAccent, other.homeAccent, t)!,
      accentForeground: Color.lerp(accentForeground, other.accentForeground, t)!,
      emotionBackground: Color.lerp(emotionBackground, other.emotionBackground, t)!,
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

const Map<String, EmotionTone> _emotionTonesLight = {
  'happy': EmotionTone(Color(0xFFFFE9C7), Color(0xFF7A4B00)),
  'laughing': EmotionTone(Color(0xFFFFD9B0), Color(0xFF7A3E00)),
  'funny': EmotionTone(Color(0xFFFFD5D8), Color(0xFF7A2F3A)),
  'silly': EmotionTone(Color(0xFFE8F7C5), Color(0xFF4F6A00)),
  'confident': EmotionTone(Color(0xFFF6E1FF), Color(0xFF5A2A7A)),
  'loving': EmotionTone(Color(0xFFFFD6E8), Color(0xFF7A2E62)),
  'kissy': EmotionTone(Color(0xFFFFC8DE), Color(0xFF6F2456)),
  'embarrassed': EmotionTone(Color(0xFFF9D6C8), Color(0xFF7A3A2C)),
  'winking': EmotionTone(Color(0xFFFFF1B8), Color(0xFF7A5200)),
  'sad': EmotionTone(Color(0xFFD6E8FF), Color(0xFF2E5A87)),
  'crying': EmotionTone(Color(0xFFC8DFFF), Color(0xFF264B7A)),
  'sleepy': EmotionTone(Color(0xFFDDE4F7), Color(0xFF4A5B7A)),
  'angry': EmotionTone(Color(0xFFFFC7C2), Color(0xFF8A1D1D)),
  'surprised': EmotionTone(Color(0xFFFFE3B3), Color(0xFF7A4B00)),
  'shocked': EmotionTone(Color(0xFFFFD0A8), Color(0xFF7A3A00)),
  'thinking': EmotionTone(Color(0xFFD6F2ED), Color(0xFF2F5C57)),
  'relaxed': EmotionTone(Color(0xFFD0F1E0), Color(0xFF2F6B5C)),
  'cool': EmotionTone(Color(0xFFCDEBFF), Color(0xFF2B5C7A)),
  'delicious': EmotionTone(Color(0xFFFFE0C4), Color(0xFF7A3E1F)),
  'confused': EmotionTone(Color(0xFFE7E1F2), Color(0xFF5A5470)),
  'neutral': EmotionTone(Color(0xFFE7F0FF), Color(0xFF2F3E5C)),
};

