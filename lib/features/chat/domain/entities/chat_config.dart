import '../../../../core/system/ota/model/device_info.dart';

class ChatConfig {
  const ChatConfig({
    required this.url,
    required this.accessToken,
    required this.deviceInfo,
  });

  final String url;
  final String accessToken;
  final DeviceInfo deviceInfo;
}
