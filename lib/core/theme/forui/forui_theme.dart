import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class AppForuiTheme {
  const AppForuiTheme._();

  static FThemeData light() => FThemes.zinc.light;

  static FThemeData dark() => FThemes.zinc.dark;

  static FThemeData themeForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark() : light();
  }
}
