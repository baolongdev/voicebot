import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../capabilities/protocol/protocol.dart';
import '../../theme/theme_palette.dart';

class UiSettingsStore {
  UiSettingsStore(this._storage);

  final FlutterSecureStorage _storage;

  static const _themeModeKey = 'ui_theme_mode';
  static const _themePaletteKey = 'ui_theme_palette';
  static const _textScaleKey = 'ui_text_scale';
  static const _listeningModeKey = 'ui_listening_mode';

  Future<ThemeMode?> readThemeMode() async {
    final value = await _storage.read(key: _themeModeKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final mode in ThemeMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return null;
  }

  Future<void> writeThemeMode(ThemeMode mode) async {
    await _storage.write(key: _themeModeKey, value: mode.name);
  }

  Future<AppThemePalette?> readThemePalette() async {
    final value = await _storage.read(key: _themePaletteKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final palette in AppThemePalette.values) {
      if (palette.name == value) {
        return palette;
      }
    }
    return null;
  }

  Future<void> writeThemePalette(AppThemePalette palette) async {
    await _storage.write(key: _themePaletteKey, value: palette.name);
  }

  Future<double?> readTextScale() async {
    final value = await _storage.read(key: _textScaleKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> writeTextScale(double scale) async {
    await _storage.write(key: _textScaleKey, value: scale.toString());
  }

  Future<ListeningMode?> readListeningMode() async {
    final value = await _storage.read(key: _listeningModeKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final mode in ListeningMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return null;
  }

  Future<void> writeListeningMode(ListeningMode mode) async {
    await _storage.write(key: _listeningModeKey, value: mode.name);
  }
}
