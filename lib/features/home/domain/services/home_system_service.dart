import 'package:audio_router/audio_router.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../entities/home_wifi_network.dart';

abstract class HomeSystemService {
  Future<int?> fetchBatteryLevel();
  Stream<BatteryState> get batteryStateStream;

  Future<List<ConnectivityResult>> fetchConnectivity();
  Stream<List<ConnectivityResult>> get connectivityStream;

  Future<String?> fetchWifiName();
  Future<String?> fetchCarrierName();

  Future<double?> fetchVolume();
  Stream<double> get volumeStream;
  Future<void> setVolume(double volume);

  Future<AudioDevice?> fetchAudioDevice();
  Stream<AudioDevice?> get audioDeviceStream;

  Future<bool> connectToWifi(HomeWifiNetwork network, String password);
  Future<void> openWifiSettings();

  Future<List<HomeWifiNetwork>> scanWifiNetworks();

  Future<void> dispose();
}
