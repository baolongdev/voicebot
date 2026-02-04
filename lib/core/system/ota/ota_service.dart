import 'model/device_info.dart';
import 'model/ota_result.dart';

// Ported from Android Kotlin: FormRepository.kt
abstract class OtaService {
  OtaResult? get otaResult;
  DeviceInfo? get deviceInfo;
  Future<void> checkVersion(String url);
}
