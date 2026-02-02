import 'dart:async';
import 'dart:io';

import 'package:audio_router/audio_router.dart';
import 'package:audio_router/audio_router_platform_interface.dart';
import 'package:app_settings/app_settings.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:carrier_info/carrier_info.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../domain/entities/home_wifi_network.dart';
import '../../domain/services/home_system_service.dart';

class HomeSystemServiceImpl implements HomeSystemService {
  HomeSystemServiceImpl({
    Battery? battery,
    Connectivity? connectivity,
    NetworkInfo? networkInfo,
    AudioRouter? audioRouter,
  })  : _battery = battery ?? Battery(),
        _connectivity = connectivity ?? Connectivity(),
        _networkInfo = networkInfo ?? NetworkInfo(),
        _audioRouter = audioRouter ?? AudioRouter() {
    FlutterVolumeController.addListener(
      _handleVolumeChanged,
      stream: AudioStream.music,
    );
    if (Platform.isAndroid) {
      unawaited(
        FlutterVolumeController.setAndroidAudioStream(
          stream: AudioStream.music,
        ),
      );
    }
  }

  final Battery _battery;
  final Connectivity _connectivity;
  final NetworkInfo _networkInfo;
  final AudioRouter _audioRouter;
  final StreamController<double> _volumeController =
      StreamController<double>.broadcast();

  @override
  Future<int?> fetchBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<BatteryState> get batteryStateStream => _battery.onBatteryStateChanged;

  @override
  Future<List<ConnectivityResult>> fetchConnectivity() async {
    try {
      return await _connectivity.checkConnectivity();
    } catch (_) {
      return <ConnectivityResult>[];
    }
  }

  @override
  Stream<List<ConnectivityResult>> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  @override
  Future<String?> fetchWifiName() async {
    try {
      return await _networkInfo.getWifiName();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> fetchCarrierName() async {
    try {
      if (Platform.isAndroid) {
        final info = await CarrierInfo.getAndroidInfo();
        return _androidCarrierName(info);
      }
      if (Platform.isIOS) {
        final info = await CarrierInfo.getIosInfo();
        return _iosCarrierName(info);
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<double?> fetchVolume() async {
    try {
      return await FlutterVolumeController.getVolume(
        stream: AudioStream.music,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<double> get volumeStream => _volumeController.stream;

  @override
  Future<void> setVolume(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    try {
      await FlutterVolumeController.setVolume(
        clamped,
        stream: AudioStream.music,
      );
    } catch (_) {}
    _handleVolumeChanged(clamped);
  }

  @override
  Future<AudioDevice?> fetchAudioDevice() async {
    try {
      return await AudioRouterPlatform.instance.getCurrentDevice();
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AudioDevice?> get audioDeviceStream =>
      _audioRouter.currentDeviceStream;

  @override
  Future<bool> connectToWifi(HomeWifiNetwork network, String password) async {
    try {
      if (!network.secured) {
        await PluginWifiConnect.connectToSecureNetwork(
          network.ssid,
          '',
          isWep: false,
          isWpa3: false,
        );
        return true;
      }
      final caps = network.capabilities.toUpperCase();
      final isWep = caps.contains('WEP');
      final isWpa3 = caps.contains('WPA3') || caps.contains('SAE');
      await PluginWifiConnect.connectToSecureNetwork(
        network.ssid,
        password,
        isWep: isWep,
        isWpa3: isWpa3,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> openWifiSettings() async {
    if (Platform.isAndroid) {
      await AppSettings.openAppSettings(type: AppSettingsType.wifi);
      return;
    }
    await AppSettings.openAppSettings();
  }

  @override
  Future<List<HomeWifiNetwork>> scanWifiNetworks() async {
    final current = _cleanWifiName(await fetchWifiName());
    if (!Platform.isAndroid) {
      if (current != null && current.isNotEmpty) {
        return [
          HomeWifiNetwork(
            ssid: current,
            secured: true,
            level: -50,
            bandLabel: _bandLabel(current),
            securityLabel: 'Đang kết nối',
            capabilities: '',
            isCurrent: true,
          ),
        ];
      }
      return [];
    }

    final canStart = await WiFiScan.instance.canStartScan(
      askPermissions: true,
    );
    if (canStart == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
    }

    final canGet = await WiFiScan.instance.canGetScannedResults(
      askPermissions: true,
    );
    if (canGet != CanGetScannedResults.yes) {
      return [];
    }

    final results = await WiFiScan.instance.getScannedResults();
    final networks = results
        .where((ap) => ap.ssid.isNotEmpty)
        .map((ap) => HomeWifiNetwork(
              ssid: ap.ssid,
              secured: _isSecured(ap.capabilities),
              level: ap.level,
              bandLabel: _bandLabel(ap.ssid),
              securityLabel: _securityLabel(ap.capabilities),
              capabilities: ap.capabilities,
              isCurrent: current != null && ap.ssid == current,
            ))
        .toList()
      ..sort((a, b) {
        if (a.isCurrent != b.isCurrent) {
          return a.isCurrent ? -1 : 1;
        }
        return b.level.compareTo(a.level);
      });

    return networks;
  }

  @override
  Future<void> dispose() async {
    FlutterVolumeController.removeListener();
    await _volumeController.close();
  }

  void _handleVolumeChanged(double volume) {
    if (_volumeController.isClosed) {
      return;
    }
    _volumeController.add(volume);
  }

  String? _androidCarrierName(AndroidCarrierData? info) {
    if (info == null) {
      return null;
    }
    final telephony = info.telephonyInfo;
    if (telephony.isNotEmpty) {
      final first = telephony.first;
      final name = _firstNonEmpty([
        first.networkOperatorName,
        first.carrierName,
        first.displayName,
      ]);
      if (name != null) {
        return name;
      }
    }
    final subs = info.subscriptionsInfo;
    if (subs.isNotEmpty) {
      final first = subs.first;
      return _firstNonEmpty([first.displayName]);
    }
    return null;
  }

  String? _iosCarrierName(IosCarrierData? info) {
    if (info == null) {
      return null;
    }
    final carriers = info.carrierData;
    if (carriers.isEmpty) {
      return null;
    }
    final first = carriers.first;
    return _firstNonEmpty([
      first.carrierName,
      first.mobileNetworkCode,
      first.mobileCountryCode,
    ]);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  bool _isSecured(String capabilities) {
    final caps = capabilities.toUpperCase();
    return caps.contains('WPA') ||
        caps.contains('WEP') ||
        caps.contains('EAP') ||
        caps.contains('SAE') ||
        caps.contains('OWE');
  }

  String _bandLabel(String ssid) {
    final upper = ssid.toUpperCase();
    if (upper.contains('5G') || upper.contains('5GHZ')) {
      return '5G';
    }
    return '2.4G';
  }

  String _securityLabel(String capabilities) {
    final caps = capabilities.toUpperCase();
    if (caps.contains('WPA3') || caps.contains('SAE')) {
      return 'WPA3';
    }
    if (caps.contains('WPA2')) {
      return 'WPA2';
    }
    if (caps.contains('WPA')) {
      return 'WPA';
    }
    if (caps.contains('WEP')) {
      return 'WEP';
    }
    if (caps.contains('OWE')) {
      return 'OWE';
    }
    return 'Open';
  }

  String? _cleanWifiName(String? name) {
    if (name == null) {
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '<unknown ssid>') {
      return null;
    }
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }
}
