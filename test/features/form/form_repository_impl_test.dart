import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:voicebot/core/system/ota/model/device_info.dart';
import 'package:voicebot/core/system/ota/model/ota_result.dart';
import 'package:voicebot/core/system/ota/ota.dart' as core_ota;
import 'package:voicebot/features/form/domain/models/server_form_data.dart';
import 'package:voicebot/features/form/domain/repositories/form_result.dart';
import 'package:voicebot/features/form/infrastructure/repositories/form_repository_impl.dart';
import 'package:voicebot/features/form/infrastructure/repositories/settings_repository_impl.dart';

class _FakeOta implements core_ota.Ota {
  _FakeOta({
    this.otaResult,
    this.deviceInfo,
  });

  int checkCalls = 0;
  String? lastUrl;

  @override
  OtaResult? otaResult;

  @override
  DeviceInfo? deviceInfo;

  @override
  Future<void> checkVersion(String url) async {
    checkCalls += 1;
    lastUrl = url;
  }
}

void main() {
  group('FormRepositoryImpl submitForm (OTA validation path)', () {
    test(
        'Given xiaoZhi server, When submitForm, Then calls OTA checkVersion and emits XiaoZhiResult',
        () async {
      final otaResult = OtaResult(
        mqttConfig: const MqttConfig(
          endpoint: 'ssl://mqtt.example.com',
          clientId: 'client-1',
          username: 'user',
          password: 'pass',
          publishTopic: 'pub',
          subscribeTopic: 'sub',
        ),
        activation: null,
        serverTime: null,
        firmware: null,
      );
      final fakeOta = _FakeOta(
        otaResult: otaResult,
        deviceInfo: DummyDataGenerator.generate(),
      );
      final settings = SettingsRepositoryImpl();
      final repo = FormRepositoryImpl(
        ota: fakeOta,
        settingsRepository: settings,
      );
      final formData = const ServerFormData(
        serverType: ServerType.xiaoZhi,
        xiaoZhiConfig: XiaoZhiConfig(
          webSocketUrl: 'wss://api.tenclass.net/xiaozhi/v1/',
          qtaUrl: 'https://api.tenclass.net/xiaozhi/ota/',
          transportType: TransportType.mqtt,
        ),
      );

      final completer = Completer<FormResult>();
      final sub = repo.resultStream.listen((event) {
        if (event is XiaoZhiResult && !completer.isCompleted) {
          completer.complete(event);
        }
      });

      await repo.submitForm(formData);
      await completer.future;

      expect(fakeOta.checkCalls, equals(1));
      expect(fakeOta.lastUrl, equals(formData.xiaoZhiConfig.qtaUrl));
      expect(settings.transportType, equals(TransportType.mqtt));
      expect(settings.webSocketUrl, equals(formData.xiaoZhiConfig.webSocketUrl));
      expect(settings.mqttConfig, equals(otaResult.mqttConfig));

      await sub.cancel();
    });

    test(
        'Given selfHost server, When submitForm, Then does not call OTA and emits SelfHostResult',
        () async {
      final fakeOta = _FakeOta(deviceInfo: DummyDataGenerator.generate());
      final settings = SettingsRepositoryImpl();
      final repo = FormRepositoryImpl(
        ota: fakeOta,
        settingsRepository: settings,
      );
      final formData = const ServerFormData(
        serverType: ServerType.selfHost,
        selfHostConfig: SelfHostConfig(
          webSocketUrl: 'ws://192.168.1.246:8000',
          transportType: TransportType.webSockets,
        ),
      );

      final completer = Completer<FormResult>();
      final sub = repo.resultStream.listen((event) {
        if (event is SelfHostResult && !completer.isCompleted) {
          completer.complete(event);
        }
      });

      await repo.submitForm(formData);
      await completer.future;

      expect(fakeOta.checkCalls, equals(0));
      expect(settings.transportType, equals(TransportType.webSockets));
      expect(settings.webSocketUrl, equals(formData.selfHostConfig.webSocketUrl));

      await sub.cancel();
    });
  });
}
