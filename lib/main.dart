import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:opus_dart/opus_dart.dart' as opus_dart;
import 'package:opus_flutter/opus_flutter.dart' as opus_flutter;

import 'package:voicebot/di/locator.dart';
import 'package:voicebot/presentation/app/application.dart';
import 'package:voicebot/core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  opus_dart.initOpus(await opus_flutter.load());
  if (AppConfig.fullscreenEnabled) {
    // Keep fullscreen at the app boundary so feature UI stays clean.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
  await configureDependencies();
  runApp(const Application());
}
