import '../entities/home_wifi_network.dart';
import '../entities/home_system_status.dart';

abstract class HomeSystemService {
  Future<int?> fetchBatteryLevel();
  Stream<HomeBatteryState> get batteryStateStream;

  Future<List<HomeConnectivity>> fetchConnectivity();
  Stream<List<HomeConnectivity>> get connectivityStream;

  Future<String?> fetchWifiName();
  Future<String?> fetchCarrierName();

  Future<double?> fetchVolume();
  Stream<double> get volumeStream;
  Future<void> setVolume(double volume);

  Future<HomeAudioDevice?> fetchAudioDevice();
  Stream<HomeAudioDevice?> get audioDeviceStream;

  Future<bool> connectToWifi(HomeWifiNetwork network, String password);
  Future<void> openWifiSettings();

  Future<List<HomeWifiNetwork>> scanWifiNetworks();

  Future<void> dispose();
}
