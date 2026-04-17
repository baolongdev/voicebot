import 'package:flutter/material.dart';
import 'colors.dart';

class DarkTheme {
  const DarkTheme._();

  static ThemeData get theme => DarkThemeColors.theme;

  static Color get background => DarkThemeColors.background;
  static Color get surface => DarkThemeColors.surface;
  static Color get surfaceLight => DarkThemeColors.surfaceLight;
  static Color get textPrimary => DarkThemeColors.textPrimary;
  static Color get textSecondary => DarkThemeColors.textSecondary;
  static Color get accent => DarkThemeColors.accent;
  static Color get error => DarkThemeColors.error;

  static BoxDecoration get cardDecoration => BoxDecoration(
    color: DarkThemeColors.surface,
    borderRadius: BorderRadius.circular(8),
  );

  static BoxDecoration get pillButtonDecoration => BoxDecoration(
    color: DarkThemeColors.surfaceLight,
    borderRadius: BorderRadius.circular(500),
  );

  static BoxDecoration get accentButtonDecoration => BoxDecoration(
    color: DarkThemeColors.accent,
    borderRadius: BorderRadius.circular(500),
  );

  static BoxDecoration get circularButtonDecoration => BoxDecoration(
    color: DarkThemeColors.surfaceLight,
    shape: BoxShape.circle,
  );

  static InputDecoration get searchInputDecoration => InputDecoration(
    filled: true,
    fillColor: DarkThemeColors.surfaceLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(500),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(500),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(500),
      borderSide: const BorderSide(color: DarkThemeColors.accent, width: 2),
    ),
    hintStyle: const TextStyle(color: DarkThemeColors.textMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  static InputDecoration get outlinedInputDecoration => InputDecoration(
    filled: true,
    fillColor: DarkThemeColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DarkThemeColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DarkThemeColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: DarkThemeColors.accent, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  static TextStyle get headingStyle => const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: DarkThemeColors.textPrimary,
  );

  static TextStyle get titleStyle => const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: DarkThemeColors.textPrimary,
  );

  static TextStyle get bodyStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: DarkThemeColors.textPrimary,
  );

  static TextStyle get bodyBoldStyle => const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: DarkThemeColors.textPrimary,
  );

  static TextStyle get buttonStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: DarkThemeColors.textPrimary,
  );

  static TextStyle get navStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: DarkThemeColors.textSecondary,
  );

  static TextStyle get navActiveStyle => const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: DarkThemeColors.textPrimary,
  );

  static TextStyle get captionStyle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: DarkThemeColors.textSecondary,
  );
}
