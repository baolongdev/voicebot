import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:voicebot/core/system/ota/model/device_info.dart';
import 'package:voicebot/core/system/ota/model/ota_result.dart';
import 'package:voicebot/core/system/ota/ota_service.dart' as core_ota;
import 'package:voicebot/features/chat/application/state/chat_session.dart';
import 'package:voicebot/features/chat/application/state/chat_state.dart';
import 'package:voicebot/features/form/domain/models/server_form_data.dart';
import 'package:voicebot/features/form/infrastructure/repositories/settings_repository.dart';
import 'package:voicebot/features/home/application/state/home_cubit.dart';
import 'package:voicebot/features/home/domain/entities/home_system_status.dart';
import 'package:voicebot/features/home/domain/entities/home_wifi_network.dart';
import 'package:voicebot/features/home/domain/services/home_system_service.dart';

class _FakeHomeSystemService implements HomeSystemService {
  int? batteryLevel;
  List<HomeConnectivity> connectivity = const <HomeConnectivity>[];
  String? wifiName;
  String? carrierName;
  double? volume;
  HomeAudioDevice? audioDevice;
  List<HomeWifiNetwork> wifiNetworks = const <HomeWifiNetwork>[];
  bool connectResult = true;

  final StreamController<HomeBatteryState> _batteryStateController =
      StreamController<HomeBatteryState>.broadcast();
  final StreamController<List<HomeConnectivity>> _connectivityController =
      StreamController<List<HomeConnectivity>>.broadcast();
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();
  final StreamController<HomeAudioDevice?> _audioDeviceController =
      StreamController<HomeAudioDevice?>.broadcast();

  @override
  Future<int?> fetchBatteryLevel() async => batteryLevel;

  @override
  Stream<HomeBatteryState> get batteryStateStream =>
      _batteryStateController.stream;

  @override
  Future<List<HomeConnectivity>> fetchConnectivity() async => connectivity;

  @override
  Stream<List<HomeConnectivity>> get connectivityStream =>
      _connectivityController.stream;

  @override
  Future<String?> fetchWifiName() async => wifiName;

  @override
  Future<String?> fetchCarrierName() async => carrierName;

  @override
  Future<double?> fetchVolume() async => volume;

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  @override
  Future<HomeAudioDevice?> fetchAudioDevice() async => audioDevice;

  @override
  Stream<HomeAudioDevice?> get audioDeviceStream =>
      _audioDeviceController.stream;

  @override
  Future<List<HomeWifiNetwork>> scanWifiNetworks() async => wifiNetworks;

  @override
  Future<bool> connectToWifi(
    HomeWifiNetwork network,
    String password,
  ) async =>
      connectResult;

  @override
  Future<void> setVolume(double value) async {
    volume = value;
    _volumeController.add(value);
  }

  @override
  Future<void> openWifiSettings() async {}

  @override
  Future<void> dispose() async {
    await _batteryStateController.close();
    await _connectivityController.close();
    await _volumeController.close();
    await _audioDeviceController.close();
  }

  void emitBatteryState(HomeBatteryState state) {
    _batteryStateController.add(state);
  }

  void emitConnectivity(List<HomeConnectivity> results) {
    _connectivityController.add(results);
  }

  void emitVolume(double value) {
    _volumeController.add(value);
  }
}

class _FakeSettingsRepository implements SettingsRepository {
  @override
  TransportType transportType = TransportType.mqtt;

  @override
  MqttConfig? mqttConfig;

  @override
  String? webSocketUrl;

  @override
  String? webSocketToken;

  @override
  bool get hasValidWebSocketConfig =>
      (webSocketUrl ?? '').isNotEmpty && (webSocketToken ?? '').isNotEmpty;

  @override
  bool get hasValidMqttConfig => mqttConfig != null;

  @override
  void applyOtaResult(OtaResult result) {
    mqttConfig = result.mqttConfig;
    if (result.websocket != null) {
      webSocketUrl = result.websocket!.url;
      webSocketToken = result.websocket!.token;
    }
  }

  @override
  void normalizeTransport() {}

  @override
  Future<void> hydrate() async {}
}

class _FakeOta implements core_ota.OtaService {
  _FakeOta({
    this.deviceInfo,
    this.nextResult,
  });

  @override
  OtaResult? otaResult;

  @override
  DeviceInfo? deviceInfo;

  OtaResult? nextResult;

  int checkCalls = 0;

  @override
  Future<void> checkVersion(String url) async {
    checkCalls += 1;
    if (nextResult != null) {
      otaResult = nextResult;
    }
  }

  @override
  Future<void> refreshIdentity() async {}
}

class _FakeChatSession implements ChatSession {
  _FakeChatSession({ChatState? initial})
      : _state = initial ?? ChatState.initial();

  final StreamController<ChatState> _controller =
      StreamController<ChatState>.broadcast();
  ChatState _state;

  @override
  Stream<ChatState> get stream => _controller.stream;

  @override
  ChatState get state => _state;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect({bool userInitiated = true}) async {}

  void emit(ChatState state) {
    _state = state;
    _controller.add(state);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

void main() {
  test('HomeCubit initialize populates system info', () async {
    final system = _FakeHomeSystemService()
      ..batteryLevel = 88
      ..connectivity = <HomeConnectivity>[HomeConnectivity.wifi]
      ..wifiName = 'OfficeWiFi'
      ..carrierName = 'Carrier'
      ..volume = 0.7;
    final cubit = HomeCubit(
      settingsRepository: _FakeSettingsRepository(),
      ota: _FakeOta(deviceInfo: DummyDataGenerator.generate()),
      chatCubit: _FakeChatSession(),
      systemService: system,
    );

    await cubit.initialize();

    expect(cubit.state.batteryLevel, equals(88));
    expect(cubit.state.connectivity, equals([HomeConnectivity.wifi]));
    expect(cubit.state.wifiName, equals('OfficeWiFi'));
    expect(cubit.state.carrierName, equals('Carrier'));
    expect(cubit.state.volume, equals(0.7));
    await cubit.close();
  });

  test('HomeCubit updates battery and connectivity streams', () async {
    final system = _FakeHomeSystemService();
    final cubit = HomeCubit(
      settingsRepository: _FakeSettingsRepository(),
      ota: _FakeOta(deviceInfo: DummyDataGenerator.generate()),
      chatCubit: _FakeChatSession(),
      systemService: system,
    );

    await cubit.initialize();

    system.emitBatteryState(HomeBatteryState.charging);
    system.emitConnectivity(<HomeConnectivity>[HomeConnectivity.mobile]);
    await pumpEventQueue();

    expect(cubit.state.batteryState, equals(HomeBatteryState.charging));
    expect(cubit.state.connectivity, equals([HomeConnectivity.mobile]));
    await cubit.close();
  });

  test('HomeCubit refreshWifiNetworks uses service result', () async {
    final system = _FakeHomeSystemService()
      ..wifiNetworks = const [
        HomeWifiNetwork(
          ssid: 'Lab',
          secured: true,
          level: -45,
          bandLabel: '5G',
          securityLabel: 'WPA2',
          capabilities: 'WPA2',
          isCurrent: true,
        ),
      ];
    final cubit = HomeCubit(
      settingsRepository: _FakeSettingsRepository(),
      ota: _FakeOta(deviceInfo: DummyDataGenerator.generate()),
      chatCubit: _FakeChatSession(),
      systemService: system,
    );

    await cubit.initialize();
    await cubit.refreshWifiNetworks();

    expect(cubit.state.wifiNetworks.length, equals(1));
    expect(cubit.state.wifiLoading, isFalse);
    await cubit.close();
  });

  test('HomeCubit activation progress ticks', () async {
    final otaResult = OtaResult(
      mqttConfig: const MqttConfig(
        endpoint: 'ssl://mqtt.example.com',
        clientId: 'client-1',
        username: 'user',
        password: 'pass',
        publishTopic: 'pub',
        subscribeTopic: 'sub',
      ),
      websocket: null,
      activation: const Activation(code: 'ABC123', message: 'OK'),
      serverTime: null,
      firmware: null,
    );
    final ota = _FakeOta(
      deviceInfo: DummyDataGenerator.generate(),
      nextResult: otaResult,
    );
    final cubit = HomeCubit(
      settingsRepository: _FakeSettingsRepository(),
      ota: ota,
      chatCubit: _FakeChatSession(),
      systemService: _FakeHomeSystemService(),
    );

    await cubit.connect();

    expect(cubit.state.awaitingActivation, isTrue);
    final before = cubit.state.activationProgress;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(cubit.state.activationProgress, isNot(equals(before)));
    await cubit.close();
  });
}
