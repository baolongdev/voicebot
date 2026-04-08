import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import '../../capabilities/protocol/protocol.dart';
import '../../theme/theme_palette.dart';
import 'default_settings.dart';

class DefaultSettingsLoader {
  const DefaultSettingsLoader._();

  static const String assetPath = 'assets/config/default_settings.yaml';

  static Future<DefaultSettings> load({
    AssetBundle? bundle,
    String path = assetPath,
  }) async {
    final targetBundle = bundle ?? rootBundle;
    try {
      final raw = await targetBundle.loadString(path);
      return parse(raw);
    } catch (_) {
      return DefaultSettings.fallback;
    }
  }

  static Future<void> loadIntoRegistry({
    AssetBundle? bundle,
    String path = assetPath,
  }) async {
    final settings = await load(bundle: bundle, path: path);
    DefaultSettingsRegistry.setCurrent(settings);
  }

  static DefaultSettings parse(String raw) {
    try {
      final parsed = loadYaml(raw);
      if (parsed is! YamlMap) {
        return DefaultSettings.fallback;
      }
      final root = _toPlainMap(parsed);
      return _parseRoot(root);
    } catch (_) {
      return DefaultSettings.fallback;
    }
  }

  static DefaultSettings _parseRoot(Map<String, dynamic> root) {
    final fallback = DefaultSettings.fallback;
    return DefaultSettings(
      theme: _parseTheme(root['theme'], fallback.theme),
      logging: _parseLogging(root['logging'], fallback.logging),
      audio: _parseAudio(root['audio'], fallback.audio),
      chat: _parseChat(root['chat'], fallback.chat),
      camera: _parseCamera(root['camera'], fallback.camera),
      carousel: _parseCarousel(root['carousel'], fallback.carousel),
      app: _parseApp(root['app'], fallback.app),
      device: _parseDevice(root['device'], fallback.device),
      github: _parseGitHub(root['github'], fallback.github),
      webHost: _parseWebHost(root['web_host'], fallback.webHost),
      home: _parseHome(root['home'], fallback.home),
    );
  }

  static ThemeDefaultSettings _parseTheme(
    Object? raw,
    ThemeDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return ThemeDefaultSettings(
      mode: _parseThemeMode(map['mode']) ?? fallback.mode,
      palette: _parsePalette(map['palette']) ?? fallback.palette,
      textScale:
          _asDouble(map['text_scale'])?.clamp(0.85, 1.5) ?? fallback.textScale,
    );
  }

  static LoggingDefaultSettings _parseLogging(
    Object? raw,
    LoggingDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return LoggingDefaultSettings(
      verbose: _asBool(map['verbose']) ?? fallback.verbose,
      logAudio: _asBool(map['log_audio']) ?? fallback.logAudio,
      logMcp: _asBool(map['log_mcp']) ?? fallback.logMcp,
      logWebsocket: _asBool(map['log_websocket']) ?? fallback.logWebsocket,
      logNetwork: _asBool(map['log_network']) ?? fallback.logNetwork,
    );
  }

  static AudioDefaultSettings _parseAudio(
    Object? raw,
    AudioDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return AudioDefaultSettings(
      vadEnabled: _asBool(map['vad_enabled']) ?? fallback.vadEnabled,
      vadThreshold:
          _asInt(map['vad_threshold'])?.clamp(0, 1000) ?? fallback.vadThreshold,
      minBufferFrames:
          _asInt(map['min_buffer_frames'])?.clamp(1, 10) ??
          fallback.minBufferFrames,
      maxBufferFrames:
          _asInt(map['max_buffer_frames'])?.clamp(1, 20) ??
          fallback.maxBufferFrames,
    );
  }

  static ChatDefaultSettings _parseChat(
    Object? raw,
    ChatDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return ChatDefaultSettings(
      listeningMode:
          _parseListeningMode(map['listening_mode']) ?? fallback.listeningMode,
      textSendMode:
          _parseTextSendMode(map['text_send_mode']) ?? fallback.textSendMode,
      connectGreeting:
          _asString(map['connect_greeting']) ?? fallback.connectGreeting,
      autoReconnect: _asBool(map['auto_reconnect']) ?? fallback.autoReconnect,
      relatedImagesEnabled:
          _asBool(map['related_images_enabled']) ??
          fallback.relatedImagesEnabled,
      relatedImagesMaxCount:
          _asInt(map['related_images_max_count'])?.clamp(1, 10) ??
          fallback.relatedImagesMaxCount,
      relatedImagesSearchTopK:
          _asInt(map['related_images_search_top_k'])?.clamp(1, 10) ??
          fallback.relatedImagesSearchTopK,
      relatedImagesAnimationEnabled:
          _asBool(map['related_images_animation_enabled']) ??
          fallback.relatedImagesAnimationEnabled,
    );
  }

  static CameraDefaultSettings _parseCamera(
    Object? raw,
    CameraDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return CameraDefaultSettings(
      enabled: _asBool(map['enabled']) ?? fallback.enabled,
      aspectRatio:
          _asDouble(map['aspect_ratio'])?.clamp(0.5, 3.0) ??
          fallback.aspectRatio,
      detectFaces: _asBool(map['detect_faces']) ?? fallback.detectFaces,
      faceLandmarks: _asBool(map['face_landmarks']) ?? fallback.faceLandmarks,
      faceMesh: _asBool(map['face_mesh']) ?? fallback.faceMesh,
      eyeTracking: _asBool(map['eye_tracking']) ?? fallback.eyeTracking,
    );
  }

  static CarouselDefaultSettings _parseCarousel(
    Object? raw,
    CarouselDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    final intervalMs = _asInt(map['auto_play_interval_ms']);
    final animationMs = _asInt(map['animation_duration_ms']);
    return CarouselDefaultSettings(
      height: _asDouble(map['height'])?.clamp(120.0, 360.0) ?? fallback.height,
      autoPlay: _asBool(map['auto_play']) ?? fallback.autoPlay,
      autoPlayInterval: intervalMs != null
          ? Duration(milliseconds: intervalMs.clamp(1000, 10000))
          : fallback.autoPlayInterval,
      animationDuration: animationMs != null
          ? Duration(milliseconds: animationMs.clamp(200, 3000))
          : fallback.animationDuration,
      viewportFraction:
          _asDouble(map['viewport_fraction'])?.clamp(0.4, 1.0) ??
          fallback.viewportFraction,
      enlargeCenter: _asBool(map['enlarge_center']) ?? fallback.enlargeCenter,
    );
  }

  static AppDefaultSettings _parseApp(
    Object? raw,
    AppDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return AppDefaultSettings(
      fullscreenEnabled:
          _asBool(map['fullscreen_enabled']) ?? fallback.fullscreenEnabled,
      permissionsEnabled:
          _asBool(map['permissions_enabled']) ?? fallback.permissionsEnabled,
      authEnabled: _asBool(map['auth_enabled']) ?? fallback.authEnabled,
      useNewFlow: _asBool(map['use_new_flow']) ?? fallback.useNewFlow,
    );
  }

  static DeviceDefaultSettings _parseDevice(
    Object? raw,
    DeviceDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    final mac = _asString(map['default_mac_address']);
    return DeviceDefaultSettings(
      defaultMacAddress: mac ?? fallback.defaultMacAddress,
    );
  }

  static GitHubDefaultSettings _parseGitHub(
    Object? raw,
    GitHubDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return GitHubDefaultSettings(
      autoUpdateEnabled:
          _asBool(map['auto_update_enabled']) ?? fallback.autoUpdateEnabled,
      owner: _asString(map['owner']) ?? fallback.owner,
      repo: _asString(map['repo']) ?? fallback.repo,
      assetExtension:
          _asString(map['asset_extension']) ?? fallback.assetExtension,
    );
  }

  static WebHostDefaultSettings _parseWebHost(
    Object? raw,
    WebHostDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return WebHostDefaultSettings(
      imageUploadMaxMb:
          _asInt(map['image_upload_max_mb'])?.clamp(1, 500) ??
          fallback.imageUploadMaxMb,
    );
  }

  static HomeDefaultSettings _parseHome(
    Object? raw,
    HomeDefaultSettings fallback,
  ) {
    final map = _asMap(raw);
    return HomeDefaultSettings(
      carouselMaxImages:
          _asInt(map['carousel_max_images'])?.clamp(1, 20) ??
          fallback.carouselMaxImages,
    );
  }

  static Map<String, dynamic> _toPlainMap(YamlMap source) {
    final out = <String, dynamic>{};
    source.forEach((key, value) {
      final keyString = key.toString();
      if (value is YamlMap) {
        out[keyString] = _toPlainMap(value);
      } else {
        out[keyString] = value;
      }
    });
    return out;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map(
        (key, dynamic mapValue) => MapEntry(key.toString(), mapValue),
      );
    }
    return const <String, dynamic>{};
  }

  static String? _asString(Object? value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    return null;
  }

  static bool? _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      final normalized = value.toLowerCase().trim();
      if (normalized == 'true') {
        return true;
      }
      if (normalized == 'false') {
        return false;
      }
    }
    return null;
  }

  static int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static double? _asDouble(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value.trim());
    }
    return null;
  }

  static ThemeMode? _parseThemeMode(Object? value) {
    final raw = _asString(value)?.toLowerCase();
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => null,
    };
  }

  static AppThemePalette? _parsePalette(Object? value) {
    final raw = _asString(value)?.toLowerCase();
    return switch (raw) {
      'neutral' => AppThemePalette.neutral,
      'green' => AppThemePalette.green,
      'lime' => AppThemePalette.lime,
      _ => null,
    };
  }

  static ListeningMode? _parseListeningMode(Object? value) {
    final raw = _asString(value)?.toLowerCase().replaceAll('-', '_');
    return switch (raw) {
      'always_on' || 'alwayson' => ListeningMode.alwaysOn,
      'auto_stop' || 'autostop' || 'auto' => ListeningMode.autoStop,
      'manual' => ListeningMode.manual,
      _ => null,
    };
  }

  static TextSendMode? _parseTextSendMode(Object? value) {
    final raw = _asString(value)?.toLowerCase().replaceAll('-', '_');
    return switch (raw) {
      'listen_detect' || 'listendetect' => TextSendMode.listenDetect,
      'text' => TextSendMode.text,
      _ => null,
    };
  }
}
