import 'package:flutter/material.dart';

class DarkThemeColors {
  const DarkThemeColors._();

  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF181818);
  static const Color surfaceLight = Color(0xFF1f1f1f);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFb3b3b3);
  static const Color textMuted = Color(0xFF7c7c7c);

  static const Color accent = Color(0xFF1ed760);
  static const Color accentVariant = Color(0xFF1db954);

  static const Color error = Color(0xFFf3727f);
  static const Color warning = Color(0xFFffa42b);
  static const Color info = Color(0xFF539df5);

  static const Color cardDark = Color(0xFF252525);
  static const Color cardMid = Color(0xFF272727);
  static const Color border = Color(0xFF4d4d4d);
  static const Color borderLight = Color(0xFF7c7c7c);
  static const Color separator = Color(0xFFb3b3b3);

  static const Color lightSurface = Color(0xFFeeeeee);
  static const Color lightText = Color(0xFF181818);

  static ColorScheme get colorScheme => const ColorScheme.dark(
    primary: DarkThemeColors.accent,
    onPrimary: DarkThemeColors.background,
    secondary: DarkThemeColors.accentVariant,
    onSecondary: DarkThemeColors.textPrimary,
    error: DarkThemeColors.error,
    onError: DarkThemeColors.textPrimary,
    surface: DarkThemeColors.surface,
    onSurface: DarkThemeColors.textPrimary,
    onSurfaceVariant: DarkThemeColors.textSecondary,
  );

  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: background,
      foregroundColor: textPrimary,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(500)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimary,
        side: const BorderSide(color: border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(500)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(500)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
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
        borderSide: const BorderSide(color: accent, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    iconTheme: const IconThemeData(color: textPrimary),
    dividerTheme: const DividerThemeData(color: separator, thickness: 1),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: accent,
      unselectedItemColor: textSecondary,
    ),
  );
}
