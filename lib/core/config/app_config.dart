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

  // Max upload size for each web-host document image.
  static const int webHostImageUploadMaxMb = 100;
  static const int webHostImageUploadMaxBytes =
      webHostImageUploadMaxMb * 1024 * 1024;

  // Chat related-images block toggles.
  static const bool chatRelatedImagesEnabled = true;
  static const int chatRelatedImagesMaxCount = 4;
  static const int chatRelatedImagesSearchTopK = 3;
  static const bool chatRelatedImagesAnimationEnabled = true;

  // Timeout for local web-host calls used by chat related-images lookup.
  static const int chatRelatedImagesRequestTimeoutMs = 2500;
}
