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
    // TODO: Platform install is not supported here yet.
  }

  @override
  Future<void> restartApp() async {
    // TODO: Platform restart is not supported here yet.
  }
}
