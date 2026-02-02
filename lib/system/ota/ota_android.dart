// Ported from Android Kotlin: Ota.kt
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:voicebot/system/ota/ota_platform.dart';

class OtaAndroidPlatform implements OtaPlatform {
  const OtaAndroidPlatform();

  static const MethodChannel _channel = MethodChannel('voicebot/ota');

  @override
  Future<void> installFirmware(File file) async {
    await _channel.invokeMethod<void>(
      'installFirmware',
      <String, dynamic>{'path': file.path},
    );
  }

  @override
  Future<void> restartApp() async {
    await _channel.invokeMethod<void>('restartApp');
  }

  @override
  Future<String?> getDeviceId() async {
    return _channel.invokeMethod<String>('getDeviceId');
  }
}
