import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicebot/core/config/default_settings_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('parses default settings from yaml asset', () async {
    final raw = await rootBundle.loadString(DefaultSettingsLoader.assetPath);
    final settings = DefaultSettingsLoader.parse(raw);

    expect(settings.theme.mode.name, 'system');
    expect(settings.theme.palette.name, 'green');
    expect(settings.theme.textScale, 1.0);
    expect(settings.chat.listeningMode.name, 'autoStop');
    expect(settings.chat.textSendMode.name, 'listenDetect');
    expect(settings.chat.connectGreeting, 'Xin chào');
    expect(settings.chat.autoReconnect, isTrue);
    expect(settings.camera.enabled, isTrue);
    expect(settings.camera.aspectRatio, closeTo(4 / 3, 0.0001));
    expect(settings.camera.detectFaces, isTrue);
    expect(settings.carousel.height, 240.0);
    expect(settings.carousel.autoPlay, isTrue);
    expect(settings.carousel.autoPlayInterval.inMilliseconds, 4000);
    expect(settings.carousel.animationDuration.inMilliseconds, 700);
    expect(settings.carousel.viewportFraction, 0.7);
    expect(settings.carousel.enlargeCenter, isTrue);
    expect(settings.app.fullscreenEnabled, isTrue);
    expect(settings.app.permissionsEnabled, isTrue);
    expect(settings.device.defaultMacAddress, '02:00:00:00:00:12');
  });

  test('falls back to built-in defaults on malformed yaml', () {
    final settings = DefaultSettingsLoader.parse('theme: [broken');
    expect(settings.theme.mode.name, 'system');
    expect(settings.chat.connectGreeting, 'Xin chào');
  });
}
