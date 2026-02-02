import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_colors.dart';
import 'brand_colors.dart';

final FThemeData appLightTheme = _buildTheme(
  base: FThemes.zinc.light,
  brand: BrandColors.light,
);

final FThemeData appDarkTheme = _buildTheme(
  base: FThemes.zinc.dark,
  brand: BrandColors.dark,
);

FThemeData _buildTheme({
  required FThemeData base,
  required BrandColors brand,
}) {
  final palette =
      brand == BrandColors.light ? AppColors.light : AppColors.dark;
  final colors = base.colors.copyWith(
    background: palette.background,
    foreground: palette.text,
    primary: palette.primary,
    primaryForeground: palette.onPrimary,
    secondary: palette.primaryAlt,
    secondaryForeground: palette.onPrimary,
    muted: palette.container,
    mutedForeground: palette.textLight,
    destructive: palette.error,
    destructiveForeground: palette.onError,
    error: palette.error,
    errorForeground: palette.onError,
    border: palette.outline,
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
