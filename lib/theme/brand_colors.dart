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

  static final BrandColors light = BrandColors(
    headerBackground: AppColors.light.primary,
    headerForeground: AppColors.light.onPrimary,
    homeSurface: AppColors.light.surface,
    homeAccent: AppColors.light.primaryAlt,
    accentForeground: AppColors.light.onPrimary,
    emotionBackground: AppColors.light.surface,
    emotionBorder: AppColors.light.outline,
    emotionTones: _emotionTonesLight,
  );

  static final BrandColors dark = BrandColors(
    headerBackground: AppColors.dark.primary,
    headerForeground: AppColors.dark.onPrimary,
    homeSurface: AppColors.dark.surface,
    homeAccent: AppColors.dark.primaryAlt,
    accentForeground: AppColors.dark.onPrimary,
    emotionBackground: AppColors.dark.surface,
    emotionBorder: AppColors.dark.outline,
    emotionTones: _emotionTonesDark,
  );

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
  'happy': EmotionTone(Color(0xFFFFE8A3), Color(0xFF7A5200)),
  'laughing': EmotionTone(Color(0xFFFFD780), Color(0xFF6B4300)),
  'funny': EmotionTone(Color(0xFFFFD1A3), Color(0xFF7A3F00)),
  'silly': EmotionTone(Color(0xFFEAF7B4), Color(0xFF4F6A00)),
  'confident': EmotionTone(Color(0xFFFFD9A1), Color(0xFF6B4A00)),
  'loving': EmotionTone(Color(0xFFFFD1E8), Color(0xFF7A2E62)),
  'kissy': EmotionTone(Color(0xFFFFC0DD), Color(0xFF6F2456)),
  'embarrassed': EmotionTone(Color(0xFFFAD0D6), Color(0xFF7A3A4A)),
  'winking': EmotionTone(Color(0xFFFFD1E8), Color(0xFF7A2E62)),
  'sad': EmotionTone(Color(0xFFCFE2FF), Color(0xFF2F588A)),
  'crying': EmotionTone(Color(0xFFB9D4FF), Color(0xFF2A4C7A)),
  'sleepy': EmotionTone(Color(0xFFD8E0F2), Color(0xFF4A5B7A)),
  'angry': EmotionTone(Color(0xFFFFD0D0), Color(0xFF8A1D1D)),
  'surprised': EmotionTone(Color(0xFFFFE08A), Color(0xFF7A4B00)),
  'shocked': EmotionTone(Color(0xFFFFC37A), Color(0xFF6B3500)),
  'thinking': EmotionTone(Color(0xFFD6EEE8), Color(0xFF2F5C57)),
  'relaxed': EmotionTone(Color(0xFFD5F2E3), Color(0xFF2F6B5C)),
  'cool': EmotionTone(Color(0xFFCBE9FF), Color(0xFF2B5C7A)),
  'delicious': EmotionTone(Color(0xFFFFD4B6), Color(0xFF7A3E1F)),
  'confused': EmotionTone(Color(0xFFE4E2EF), Color(0xFF5A5470)),
  'neutral': EmotionTone(Color(0xFFDDE7F1), Color(0xFF3F4C5A)),
};

const Map<String, EmotionTone> _emotionTonesDark = _emotionTonesLight;
