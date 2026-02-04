import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_colors.dart';
import 'brand_colors.dart';
import 'theme_palette.dart';

final FThemeData appLightTheme = buildTheme(
  brightness: Brightness.light,
  palette: AppThemePalette.green,
);

final FThemeData appDarkTheme = buildTheme(
  brightness: Brightness.dark,
  palette: AppThemePalette.green,
);

FThemeData buildTheme({
  required Brightness brightness,
  required AppThemePalette palette,
}) {
  final base =
      brightness == Brightness.dark ? FThemes.zinc.dark : FThemes.zinc.light;
  final paletteColors = semanticColorsForPalette(palette, brightness);
  final brand = BrandColors.fromPalette(paletteColors);
  final colors = base.colors.copyWith(
    background: paletteColors.background,
    foreground: paletteColors.text,
    primary: paletteColors.primary,
    primaryForeground: paletteColors.onPrimary,
    secondary: paletteColors.primaryAlt,
    secondaryForeground: paletteColors.onPrimary,
    muted: paletteColors.container,
    mutedForeground: paletteColors.textLight,
    destructive: paletteColors.error,
    destructiveForeground: paletteColors.onError,
    error: paletteColors.error,
    errorForeground: paletteColors.onError,
    border: paletteColors.outline,
  );

  final typography = base.typography;
  final style = FStyle.inherit(colors: colors, typography: typography);

  return FThemeData(
    colors: colors,
    typography: typography,
    style: style,
    extensions: [brand],
  );
}
