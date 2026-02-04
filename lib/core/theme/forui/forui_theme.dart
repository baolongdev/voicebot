import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../theme/theme.dart';
import '../../../theme/theme_palette.dart';

class AppForuiTheme {
  const AppForuiTheme._();

  static FThemeData light([AppThemePalette palette = AppThemePalette.green]) {
    return buildTheme(brightness: Brightness.light, palette: palette);
  }

  static FThemeData dark([AppThemePalette palette = AppThemePalette.green]) {
    return buildTheme(brightness: Brightness.dark, palette: palette);
  }

  static FThemeData themeForBrightness(
    Brightness brightness, [
    AppThemePalette palette = AppThemePalette.green,
  ]) {
    return brightness == Brightness.dark
        ? dark(palette)
        : light(palette);
  }
}
