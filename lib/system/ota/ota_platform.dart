// Ported from Android Kotlin: Ota.kt
import 'dart:io';

abstract class OtaPlatform {
  Future<void> installFirmware(File file);
  Future<void> restartApp();
}

class OtaNoopPlatform implements OtaPlatform {
  const OtaNoopPlatform();

  @override
  Future<void> installFirmware(File file) async {
    // No-op on unsupported platforms.
  }

  @override
  Future<void> restartApp() async {
    // No-op on unsupported platforms.
  }
}
