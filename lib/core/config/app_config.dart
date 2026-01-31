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
}
