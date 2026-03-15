import 'package:flutter/material.dart';

import '../../capabilities/protocol/protocol.dart';
import '../../theme/theme_palette.dart';

class DefaultSettingsRegistry {
  DefaultSettingsRegistry._();

  static DefaultSettings _current = DefaultSettings.fallback;

  static DefaultSettings get current => _current;

  static void setCurrent(DefaultSettings settings) {
    _current = settings;
  }
}

class DefaultSettings {
  const DefaultSettings({
    required this.theme,
    required this.chat,
    required this.camera,
    required this.carousel,
    required this.app,
    required this.device,
  });

  final ThemeDefaultSettings theme;
  final ChatDefaultSettings chat;
  final CameraDefaultSettings camera;
  final CarouselDefaultSettings carousel;
  final AppDefaultSettings app;
  final DeviceDefaultSettings device;

  static const DefaultSettings fallback = DefaultSettings(
    theme: ThemeDefaultSettings(
      mode: ThemeMode.system,
      palette: AppThemePalette.green,
      textScale: 1.0,
    ),
    chat: ChatDefaultSettings(
      listeningMode: ListeningMode.autoStop,
      textSendMode: TextSendMode.listenDetect,
      connectGreeting: 'Xin chào',
      autoReconnect: true,
    ),
    camera: CameraDefaultSettings(
      enabled: true,
      aspectRatio: 4 / 3,
      detectFaces: true,
      faceLandmarks: false,
      faceMesh: false,
      eyeTracking: false,
    ),
    carousel: CarouselDefaultSettings(
      height: 240.0,
      autoPlay: true,
      autoPlayInterval: Duration(milliseconds: 4000),
      animationDuration: Duration(milliseconds: 700),
      viewportFraction: 0.7,
      enlargeCenter: true,
    ),
    app: AppDefaultSettings(fullscreenEnabled: true, permissionsEnabled: true),
    device: DeviceDefaultSettings(defaultMacAddress: '02:00:00:00:00:12'),
  );
}

class ThemeDefaultSettings {
  const ThemeDefaultSettings({
    required this.mode,
    required this.palette,
    required this.textScale,
  });

  final ThemeMode mode;
  final AppThemePalette palette;
  final double textScale;
}

class ChatDefaultSettings {
  const ChatDefaultSettings({
    required this.listeningMode,
    required this.textSendMode,
    required this.connectGreeting,
    required this.autoReconnect,
  });

  final ListeningMode listeningMode;
  final TextSendMode textSendMode;
  final String connectGreeting;
  final bool autoReconnect;
}

class CameraDefaultSettings {
  const CameraDefaultSettings({
    required this.enabled,
    required this.aspectRatio,
    required this.detectFaces,
    required this.faceLandmarks,
    required this.faceMesh,
    required this.eyeTracking,
  });

  final bool enabled;
  final double aspectRatio;
  final bool detectFaces;
  final bool faceLandmarks;
  final bool faceMesh;
  final bool eyeTracking;
}

class CarouselDefaultSettings {
  const CarouselDefaultSettings({
    required this.height,
    required this.autoPlay,
    required this.autoPlayInterval,
    required this.animationDuration,
    required this.viewportFraction,
    required this.enlargeCenter,
  });

  final double height;
  final bool autoPlay;
  final Duration autoPlayInterval;
  final Duration animationDuration;
  final double viewportFraction;
  final bool enlargeCenter;
}

class AppDefaultSettings {
  const AppDefaultSettings({
    required this.fullscreenEnabled,
    required this.permissionsEnabled,
  });

  final bool fullscreenEnabled;
  final bool permissionsEnabled;
}

class DeviceDefaultSettings {
  const DeviceDefaultSettings({required this.defaultMacAddress});

  final String defaultMacAddress;
}
