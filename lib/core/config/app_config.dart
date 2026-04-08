import 'default_settings.dart';

class AppConfig {
  AppConfig._();

  static bool get authEnabled =>
      DefaultSettingsRegistry.current.app.authEnabled;

  static bool get fullscreenEnabled =>
      DefaultSettingsRegistry.current.app.fullscreenEnabled;

  static bool get permissionsEnabled =>
      DefaultSettingsRegistry.current.app.permissionsEnabled;

  static bool get useNewFlow => DefaultSettingsRegistry.current.app.useNewFlow;

  static String get connectGreetingDefault =>
      DefaultSettingsRegistry.current.chat.connectGreeting;

  static bool get autoReconnectEnabledDefault =>
      DefaultSettingsRegistry.current.chat.autoReconnect;

  static String get defaultMacAddress =>
      DefaultSettingsRegistry.current.device.defaultMacAddress;

  static int get webHostImageUploadMaxMb =>
      DefaultSettingsRegistry.current.webHost.imageUploadMaxMb;

  static int get webHostImageUploadMaxBytes =>
      webHostImageUploadMaxMb * 1024 * 1024;

  static bool get chatRelatedImagesEnabled =>
      DefaultSettingsRegistry.current.chat.relatedImagesEnabled;

  static int get chatRelatedImagesMaxCount =>
      DefaultSettingsRegistry.current.chat.relatedImagesMaxCount;

  static int get chatRelatedImagesSearchTopK =>
      DefaultSettingsRegistry.current.chat.relatedImagesSearchTopK;

  static bool get chatRelatedImagesAnimationEnabled =>
      DefaultSettingsRegistry.current.chat.relatedImagesAnimationEnabled;

  static int get homeCarouselMaxImages =>
      DefaultSettingsRegistry.current.home.carouselMaxImages;

  static const int chatRelatedImagesRequestTimeoutMs = 2500;

  static bool get githubAutoUpdateEnabled =>
      DefaultSettingsRegistry.current.github.autoUpdateEnabled;

  static String get githubOwner => DefaultSettingsRegistry.current.github.owner;

  static String get githubRepo => DefaultSettingsRegistry.current.github.repo;

  static const String githubAssetNameContains = '';

  static String get githubAssetExtension =>
      DefaultSettingsRegistry.current.github.assetExtension;

  static const int githubUpdateCheckTimeoutMs = 20000;
  static const int githubDownloadTimeoutMs = 120000;
  static const String githubToken = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );

  static const String githubUpdateJsonUrl =
      'https://raw.githubusercontent.com/baolongdev/voicebot/refs/heads/main/update.json';
}
