// Ported from Android Kotlin: Ota.kt
import 'dart:io';

abstract class OtaPlatform {
  Future<void> installFirmware(File file);
  Future<void> restartApp();
  Future<String?> getDeviceId();
  Future<String?> getMacAddress();
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

  @override
  Future<String?> getDeviceId() async {
    return null;
  }

  @override
  Future<String?> getMacAddress() async {
    return null;
  }
}
