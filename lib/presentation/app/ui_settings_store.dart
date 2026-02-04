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
  static const _connectGreetingKey = 'ui_connect_greeting';
  static const _textSendModeKey = 'ui_text_send_mode';
  static const _carouselHeightKey = 'ui_carousel_height';
  static const _carouselAutoPlayKey = 'ui_carousel_autoplay';
  static const _carouselIntervalKey = 'ui_carousel_interval_ms';
  static const _carouselAnimKey = 'ui_carousel_anim_ms';
  static const _carouselViewportKey = 'ui_carousel_viewport';
  static const _carouselEnlargeKey = 'ui_carousel_enlarge';

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

  Future<String?> readConnectGreeting() async {
    final value = await _storage.read(key: _connectGreetingKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> writeConnectGreeting(String value) async {
    await _storage.write(key: _connectGreetingKey, value: value);
  }

  Future<TextSendMode?> readTextSendMode() async {
    final value = await _storage.read(key: _textSendModeKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    for (final mode in TextSendMode.values) {
      if (mode.name == value) {
        return mode;
      }
    }
    return null;
  }

  Future<void> writeTextSendMode(TextSendMode mode) async {
    await _storage.write(key: _textSendModeKey, value: mode.name);
  }

  Future<double?> readCarouselHeight() async {
    final value = await _storage.read(key: _carouselHeightKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> writeCarouselHeight(double height) async {
    await _storage.write(key: _carouselHeightKey, value: height.toString());
  }

  Future<bool?> readCarouselAutoPlay() async {
    final value = await _storage.read(key: _carouselAutoPlayKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value == '1' || value == 'true';
  }

  Future<void> writeCarouselAutoPlay(bool enabled) async {
    await _storage.write(
      key: _carouselAutoPlayKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<int?> readCarouselIntervalMs() async {
    final value = await _storage.read(key: _carouselIntervalKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  Future<void> writeCarouselIntervalMs(int ms) async {
    await _storage.write(key: _carouselIntervalKey, value: ms.toString());
  }

  Future<int?> readCarouselAnimationMs() async {
    final value = await _storage.read(key: _carouselAnimKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return int.tryParse(value);
  }

  Future<void> writeCarouselAnimationMs(int ms) async {
    await _storage.write(key: _carouselAnimKey, value: ms.toString());
  }

  Future<double?> readCarouselViewport() async {
    final value = await _storage.read(key: _carouselViewportKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return double.tryParse(value);
  }

  Future<void> writeCarouselViewport(double value) async {
    await _storage.write(key: _carouselViewportKey, value: value.toString());
  }

  Future<bool?> readCarouselEnlarge() async {
    final value = await _storage.read(key: _carouselEnlargeKey);
    if (value == null || value.isEmpty) {
      return null;
    }
    return value == '1' || value == 'true';
  }

  Future<void> writeCarouselEnlarge(bool enabled) async {
    await _storage.write(
      key: _carouselEnlargeKey,
      value: enabled ? '1' : '0',
    );
  }
}
