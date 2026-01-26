import 'package:voicebot/core/system/ota/model/ota_result.dart';
import '../../domain/models/server_form_data.dart';
import 'settings_repository.dart';

// Ported from Android Kotlin: SettingsRepository.kt
class SettingsRepositoryImpl implements SettingsRepository {
  @override
  TransportType transportType = TransportType.mqtt;

  @override
  MqttConfig? mqttConfig;

  @override
  String? webSocketUrl;

  @override
  String? webSocketToken;
}
