import 'package:flutter_test/flutter_test.dart';

import 'package:voicebot/core/system/ota/model/device_info.dart';
import 'package:voicebot/core/system/ota/model/ota_result.dart';
import 'package:voicebot/core/system/ota/ota.dart' as core_ota;
import 'package:voicebot/features/chat/infrastructure/repositories/chat_config_provider_impl.dart';
import 'package:voicebot/features/form/domain/models/server_form_data.dart';
import 'package:voicebot/features/form/infrastructure/repositories/settings_repository_impl.dart';
import 'package:voicebot/features/form/infrastructure/repositories/settings_storage.dart';

class _FakeOta implements core_ota.Ota {
  _FakeOta(this._deviceInfo);

  final DeviceInfo _deviceInfo;

  @override
  OtaResult? otaResult;

  @override
  DeviceInfo? get deviceInfo => _deviceInfo;

  @override
  Future<void> checkVersion(String url) async {}
}

void main() {
  group('ChatConfigProviderImpl loadConfig', () {
    test('fails when websocket url missing', () async {
      final settings = SettingsRepositoryImpl(InMemorySettingsStorage());
      settings.transportType = TransportType.webSockets;
      settings.webSocketUrl = '';
      settings.webSocketToken = 'token';
      final ota = _FakeOta(DummyDataGenerator.generate());
      final provider = ChatConfigProviderImpl(settings: settings, ota: ota);

      final result = await provider.loadConfig();

      expect(result.isSuccess, isFalse);
      expect(result.failure?.code, equals('missing_url'));
    });

    test('fails when websocket token missing', () async {
      final settings = SettingsRepositoryImpl(InMemorySettingsStorage());
      settings.transportType = TransportType.webSockets;
      settings.webSocketUrl = 'wss://example.com';
      settings.webSocketToken = '';
      final ota = _FakeOta(DummyDataGenerator.generate());
      final provider = ChatConfigProviderImpl(settings: settings, ota: ota);

      final result = await provider.loadConfig();

      expect(result.isSuccess, isFalse);
      expect(result.failure?.code, equals('missing_token'));
    });

    test('fails when mqtt config missing', () async {
      final settings = SettingsRepositoryImpl(InMemorySettingsStorage());
      settings.transportType = TransportType.mqtt;
      final ota = _FakeOta(DummyDataGenerator.generate());
      final provider = ChatConfigProviderImpl(settings: settings, ota: ota);

      final result = await provider.loadConfig();

      expect(result.isSuccess, isFalse);
      expect(result.failure?.code, equals('missing_mqtt'));
    });

    test('returns config when websocket info is present', () async {
      final settings = SettingsRepositoryImpl(InMemorySettingsStorage());
      settings.transportType = TransportType.webSockets;
      settings.webSocketUrl = 'wss://example.com';
      settings.webSocketToken = 'token';
      final ota = _FakeOta(DummyDataGenerator.generate());
      final provider = ChatConfigProviderImpl(settings: settings, ota: ota);

      final result = await provider.loadConfig();

      expect(result.isSuccess, isTrue);
      expect(result.data?.url, equals('wss://example.com'));
      expect(result.data?.accessToken, equals('token'));
      expect(result.data?.transportType, equals(TransportType.webSockets));
    });

    test('returns config when mqtt info is present', () async {
      final settings = SettingsRepositoryImpl(InMemorySettingsStorage());
      settings.transportType = TransportType.mqtt;
      settings.mqttConfig = const MqttConfig(
        endpoint: 'mqtt.example.com',
        clientId: 'client-1',
        username: 'user',
        password: 'pass',
        publishTopic: 'pub',
        subscribeTopic: 'sub',
      );
      final ota = _FakeOta(DummyDataGenerator.generate());
      final provider = ChatConfigProviderImpl(settings: settings, ota: ota);

      final result = await provider.loadConfig();

      expect(result.isSuccess, isTrue);
      expect(result.data?.transportType, equals(TransportType.mqtt));
      expect(result.data?.mqttConfig?.endpoint, equals('mqtt.example.com'));
    });
  });
}
