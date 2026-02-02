import '../../../../core/system/ota/model/device_info.dart';
import '../../../form/domain/models/server_form_data.dart';
import '../../../../core/system/ota/model/ota_result.dart';

class ChatConfig {
  const ChatConfig({
    required this.url,
    required this.accessToken,
    required this.deviceInfo,
    required this.transportType,
    required this.mqttConfig,
  });

  final String url;
  final String accessToken;
  final DeviceInfo deviceInfo;
  final TransportType transportType;
  final MqttConfig? mqttConfig;
}
