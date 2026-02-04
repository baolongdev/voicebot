import 'package:flutter/material.dart';

import 'app_colors.dart';

enum AppThemePalette {
  neutral,
  green,
  lime,
}

extension AppThemePaletteX on AppThemePalette {
  String get label {
    switch (this) {
      case AppThemePalette.neutral:
        return 'Mặc định';
      case AppThemePalette.green:
        return 'Xanh lá';
      case AppThemePalette.lime:
        return 'Chanh';
    }
  }

  AppThemePaletteSpec get spec {
    switch (this) {
      case AppThemePalette.neutral:
        return _neutralSpec;
      case AppThemePalette.green:
        return _greenSpec;
      case AppThemePalette.lime:
        return _limeSpec;
    }
  }
}

AppSemanticColors semanticColorsForPalette(
  AppThemePalette palette,
  Brightness brightness,
) {
  return AppSemanticColors.fromSpec(
    brightness: brightness,
    spec: palette.spec,
  );
}

const AppThemePaletteSpec _neutralSpec = AppThemePaletteSpec(
  primaryHue: 0,
  accentHue: 0,
  primarySat: 0.0,
  primaryLig: AppHslTokens.firstLig,
  primaryAltLig: AppHslTokens.firstAltLig,
  titleSat: 0.0,
  titleLig: AppHslTokens.titleLig,
  textSat: 0.0,
  textLig: AppHslTokens.textLig,
  textLightSat: 0.0,
  textLightLig: AppHslTokens.textLightLig,
  bodySat: 0.0,
  bodyLig: AppHslTokens.bodyLig,
  containerSat: 0.0,
  containerLig: AppHslTokens.containerLig,
);

const AppThemePaletteSpec _greenSpec = AppThemePaletteSpec(
  primaryHue: AppHslTokens.firstHue,
  accentHue: AppHslTokens.secondHue,
  primarySat: AppHslTokens.firstSat,
  primaryLig: AppHslTokens.firstLig,
  primaryAltLig: AppHslTokens.firstAltLig,
  titleSat: AppHslTokens.titleSat,
  titleLig: AppHslTokens.titleLig,
  textSat: AppHslTokens.textSat,
  textLig: AppHslTokens.textLig,
  textLightSat: AppHslTokens.textLightSat,
  textLightLig: AppHslTokens.textLightLig,
  bodySat: AppHslTokens.bodySat,
  bodyLig: AppHslTokens.bodyLig,
  containerSat: AppHslTokens.containerSat,
  containerLig: AppHslTokens.containerLig,
);

const AppThemePaletteSpec _limeSpec = AppThemePaletteSpec(
  primaryHue: 54.0,
  accentHue: 48.0,
  primarySat: AppHslTokens.firstSat,
  primaryLig: AppHslTokens.firstLig,
  primaryAltLig: AppHslTokens.firstAltLig,
  titleSat: AppHslTokens.titleSat,
  titleLig: AppHslTokens.titleLig,
  textSat: AppHslTokens.textSat,
  textLig: AppHslTokens.textLig,
  textLightSat: AppHslTokens.textLightSat,
  textLightLig: AppHslTokens.textLightLig,
  bodySat: AppHslTokens.bodySat,
  bodyLig: AppHslTokens.bodyLig,
  containerSat: AppHslTokens.containerSat,
  containerLig: AppHslTokens.containerLig,
);
