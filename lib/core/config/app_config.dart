class AppConfig {
  const AppConfig._();

  // Temporary switch for feature development; set to true to re-enable auth.
  static const bool authEnabled = false;

  // Fullscreen toggle for app-level system UI control.
  static const bool fullscreenEnabled = true;

  // Permission flow toggle for development; set to true to enable checks/requests.
  static const bool permissionsEnabled = true;

  // Feature flag for new v2 flow entry.
  static const bool useNewFlow = true;

  // Default text sent right after connection succeeds.
  static const String connectGreetingDefault = 'Xin chào';
  static const bool autoReconnectEnabledDefault = true;

  // Max upload size for each web-host document image.
  static const int webHostImageUploadMaxMb = 100;
  static const int webHostImageUploadMaxBytes =
      webHostImageUploadMaxMb * 1024 * 1024;

  // Chat related-images block toggles.
  static const bool chatRelatedImagesEnabled = true;
  static const int chatRelatedImagesMaxCount = 4;
  static const int chatRelatedImagesSearchTopK = 3;
  static const bool chatRelatedImagesAnimationEnabled = true;

  // Home carousel images pulled from MCP (limit per fetch).
  static const int homeCarouselMaxImages = 8;

  // Timeout for local web-host calls used by chat related-images lookup.
  static const int chatRelatedImagesRequestTimeoutMs = 2500;

  // GitHub auto-update configuration (Android).
  static const bool githubAutoUpdateEnabled = true;
  static const String githubOwner = 'baolongdev';
  static const String githubRepo = 'voicebot';
  static const String githubAssetNameContains = '';
  static const String githubAssetExtension = '.apk';
  static const int githubUpdateCheckTimeoutMs = 20000;
  static const int githubDownloadTimeoutMs = 120000;
  static const String githubToken = String.fromEnvironment(
    'GITHUB_TOKEN',
    defaultValue: '',
  );
  // update.json URL (raw) - used to check latest version info.
  static const String githubUpdateJsonUrl =
      'https://raw.githubusercontent.com/baolongdev/voicebot/refs/heads/main/update.json';
}
