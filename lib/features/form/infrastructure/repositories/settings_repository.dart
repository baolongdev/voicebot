import 'package:voicebot/core/system/ota/model/ota_result.dart';
import '../../domain/models/server_form_data.dart';

// Ported from Android Kotlin: SettingsRepository.kt
abstract class SettingsRepository {
  TransportType get transportType;
  set transportType(TransportType value);
  MqttConfig? get mqttConfig;
  set mqttConfig(MqttConfig? value);
  String? get webSocketUrl;
  set webSocketUrl(String? value);
  String? get webSocketToken;
  set webSocketToken(String? value);
}
