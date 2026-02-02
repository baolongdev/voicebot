import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../theme/theme.dart';

class AppForuiTheme {
  const AppForuiTheme._();

  static FThemeData light() => appLightTheme;

  static FThemeData dark() => appDarkTheme;

  static FThemeData themeForBrightness(Brightness brightness) {
    return brightness == Brightness.dark ? dark() : light();
  }
}
