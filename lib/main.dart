import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opus_dart/opus_dart.dart' as opus_dart;

import 'package:voicebot/di/locator.dart';
import 'package:voicebot/presentation/app/application.dart';
import 'package:voicebot/core/config/app_config.dart';
import 'package:voicebot/core/opus/opus_loader.dart';
import 'package:voicebot/core/logging/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PlatformDispatcher.instance.onError = (error, stack) {
    if (error is SocketException &&
        error.message.contains('Reading from a closed socket')) {
      AppLogger.log('Socket', 'ignored closed socket read', level: 'W');
      return true;
    }
    return false;
  };
  await _initOpus();
  if (AppConfig.fullscreenEnabled) {
    // Keep fullscreen at the app boundary so feature UI stays clean.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await configureDependencies();
  runApp(const Application());
}

Future<void> _initOpus() async {
  try {
    final lib = await loadOpusLibrary();
    opus_dart.initOpus(lib);
  } catch (e) {
    // Keep app alive; audio will be disabled if libopus is missing.
    AppLogger.log('Opus', 'init failed: $e', level: 'E');
  }
}
