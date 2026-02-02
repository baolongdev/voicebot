import 'package:flutter/material.dart';

@immutable
class AppHsl {
  const AppHsl(this.h, this.s, this.l);

  final double h;
  final double s;
  final double l;

  AppHsl withLightness(double value) {
    return AppHsl(h, s, value.clamp(0.0, 1.0));
  }

  AppHsl withSaturation(double value) {
    return AppHsl(h, value.clamp(0.0, 1.0), l);
  }

  AppHsl invertLightness({double min = 0.06, double max = 0.96}) {
    final inverted = (1.0 - l).clamp(min, max);
    return AppHsl(h, s, inverted);
  }

  Color toColor({double alpha = 1.0}) {
    final hue = ((h % 360) + 360) % 360;
    final sat = s.clamp(0.0, 1.0);
    final lig = l.clamp(0.0, 1.0);
    final a = alpha.clamp(0.0, 1.0);

    if (sat == 0) {
      final v = (lig * 255).round();
      return Color.fromARGB((a * 255).round(), v, v, v);
    }

    final c = (1 - (2 * lig - 1).abs()) * sat;
    final hPrime = hue / 60.0;
    final x = c * (1 - (hPrime % 2 - 1).abs());

    double r1 = 0;
    double g1 = 0;
    double b1 = 0;

    if (hPrime < 1) {
      r1 = c;
      g1 = x;
    } else if (hPrime < 2) {
      r1 = x;
      g1 = c;
    } else if (hPrime < 3) {
      g1 = c;
      b1 = x;
    } else if (hPrime < 4) {
      g1 = x;
      b1 = c;
    } else if (hPrime < 5) {
      r1 = x;
      b1 = c;
    } else {
      r1 = c;
      b1 = x;
    }

    final m = lig - c / 2;
    final r = (r1 + m).clamp(0.0, 1.0);
    final g = (g1 + m).clamp(0.0, 1.0);
    final b = (b1 + m).clamp(0.0, 1.0);

    return Color.fromARGB(
      (a * 255).round(),
      (r * 255).round(),
      (g * 255).round(),
      (b * 255).round(),
    );
  }
}

class AppHslTokens {
  const AppHslTokens._();

  static const double firstHue = 100.52;
  static const double secondHue = 90.86;

  static const double firstSat = 0.58;
  static const double firstLig = 0.62;
  static const double firstAltLig = 0.56;

  static const double titleSat = 0.15;
  static const double titleLig = 0.95;

  static const double textSat = 0.08;
  static const double textLig = 0.75;

  static const double textLightSat = 0.04;
  static const double textLightLig = 0.55;

  static const double bodySat = 0.48;
  static const double bodyLig = 0.08;

  static const double containerSat = 0.32;
  static const double containerLig = 0.12;

  static const AppHsl firstColor = AppHsl(firstHue, firstSat, firstLig);
  static const AppHsl firstColorAlt = AppHsl(firstHue, firstSat, firstAltLig);
  static const AppHsl titleColor = AppHsl(secondHue, titleSat, titleLig);
  static const AppHsl textColor = AppHsl(secondHue, textSat, textLig);
  static const AppHsl textColorLight = AppHsl(secondHue, textLightSat, textLightLig);
  static const AppHsl bodyColor = AppHsl(secondHue, bodySat, bodyLig);
  static const AppHsl containerColor = AppHsl(secondHue, containerSat, containerLig);

  static const double dangerHue = 4;
  static const AppHsl dangerColor = AppHsl(dangerHue, 0.60, 0.65);
  static const AppHsl dangerOnColor = AppHsl(dangerHue, 0.35, 0.18);
}

class AppAlphas {
  const AppAlphas._();

  static const double a04 = 0.04;
  static const double a08 = 0.08;
  static const double a12 = 0.12;
  static const double a16 = 0.16;
  static const double a24 = 0.24;
  static const double a32 = 0.32;
  static const double a48 = 0.48;
  static const double a64 = 0.64;

  static const double hover = a08;
  static const double pressed = a12;
  static const double focus = a12;
  static const double dragged = a16;
  static const double disabled = a32;

  static const double scrim = a48;
  static const double shadow = a24;
}

@immutable
class AppSemanticColors {
  const AppSemanticColors({
    required this.primary,
    required this.primaryAlt,
    required this.background,
    required this.surface,
    required this.container,
    required this.title,
    required this.text,
    required this.textLight,
    required this.onPrimary,
    required this.onBackground,
    required this.onSurface,
    required this.error,
    required this.onError,
    required this.outline,
    required this.shadow,
    required this.scrim,
    required this.stateHover,
    required this.statePressed,
    required this.stateFocus,
    required this.stateDisabled,
  });

  final Color primary;
  final Color primaryAlt;
  final Color background;
  final Color surface;
  final Color container;
  final Color title;
  final Color text;
  final Color textLight;
  final Color onPrimary;
  final Color onBackground;
  final Color onSurface;
  final Color error;
  final Color onError;
  final Color outline;
  final Color shadow;
  final Color scrim;
  final Color stateHover;
  final Color statePressed;
  final Color stateFocus;
  final Color stateDisabled;

  factory AppSemanticColors.fromTokens({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final primary = AppHslTokens.firstColor.toColor();
    final primaryAlt = AppHslTokens.firstColorAlt.toColor();

    final backgroundHsl = isDark
        ? AppHslTokens.bodyColor
        : AppHslTokens.bodyColor.invertLightness();
    final surfaceHsl = isDark
        ? AppHslTokens.containerColor
        : AppHslTokens.containerColor.invertLightness();
    final containerHsl = isDark
        ? AppHslTokens.containerColor
        : AppHslTokens.containerColor.invertLightness();

    final titleHsl = isDark
        ? AppHslTokens.titleColor
        : AppHslTokens.titleColor.invertLightness();
    final textHsl = isDark
        ? AppHslTokens.textColor
        : AppHslTokens.textColor.invertLightness();
    final textLightHsl = isDark
        ? AppHslTokens.textColorLight
        : AppHslTokens.textColorLight.invertLightness();

    final onPrimary =
        isDark ? titleHsl.toColor() : AppHslTokens.bodyColor.toColor();
    final onBackground = titleHsl.toColor();
    final onSurface = titleHsl.toColor();
    final outline = textLightHsl.toColor().withValues(
      alpha: AppAlphas.a32,
    );

    final error = AppHslTokens.dangerColor.toColor();
    final onError = AppHslTokens.dangerOnColor.toColor();

    return AppSemanticColors(
      primary: primary,
      primaryAlt: primaryAlt,
      background: backgroundHsl.toColor(),
      surface: surfaceHsl.toColor(),
      container: containerHsl.toColor(),
      title: titleHsl.toColor(),
      text: textHsl.toColor(),
      textLight: textLightHsl.toColor(),
      onPrimary: onPrimary,
      onBackground: onBackground,
      onSurface: onSurface,
      error: error,
      onError: onError,
      outline: outline,
      shadow: Colors.black.withValues(alpha: AppAlphas.shadow),
      scrim: Colors.black.withValues(alpha: AppAlphas.scrim),
      stateHover: AppHslTokens.firstColor.toColor(alpha: AppAlphas.hover),
      statePressed: AppHslTokens.firstColor.toColor(alpha: AppAlphas.pressed),
      stateFocus: AppHslTokens.firstColor.toColor(alpha: AppAlphas.focus),
      stateDisabled: AppHslTokens.firstColor.toColor(alpha: AppAlphas.disabled),
    );
  }

  ColorScheme toColorScheme(Brightness brightness) {
    return ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryAlt,
      onPrimaryContainer: onPrimary,
      secondary: primaryAlt,
      onSecondary: onPrimary,
      secondaryContainer: primaryAlt,
      onSecondaryContainer: onPrimary,
      tertiary: primaryAlt,
      onTertiary: onPrimary,
      tertiaryContainer: primaryAlt,
      onTertiaryContainer: onPrimary,
      surface: surface,
      onSurface: onSurface,
      surfaceContainerHighest: container,
      onSurfaceVariant: text,
      error: error,
      onError: onError,
      errorContainer: error,
      onErrorContainer: onError,
      outline: outline,
      outlineVariant: outline,
      shadow: shadow,
      scrim: scrim,
      surfaceTint: primary,
      inverseSurface: onSurface,
      onInverseSurface: background,
      inversePrimary: primaryAlt,
    );
  }
}

class AppColors {
  const AppColors._();

  static final AppSemanticColors light =
      AppSemanticColors.fromTokens(brightness: Brightness.light);
  static final AppSemanticColors dark =
      AppSemanticColors.fromTokens(brightness: Brightness.dark);
}
