// Ported from Android Kotlin: ServerFormData.kt
class ServerFormData {
  const ServerFormData({
    this.serverType = ServerType.xiaoZhi,
    this.xiaoZhiConfig = const XiaoZhiConfig(),
    this.selfHostConfig = const SelfHostConfig(),
  });

  final ServerType serverType;
  final XiaoZhiConfig xiaoZhiConfig;
  final SelfHostConfig selfHostConfig;
}

// Ported from Android Kotlin: ServerFormData.kt
enum ServerType {
  xiaoZhi,
  selfHost,
}

// Ported from Android Kotlin: ServerFormData.kt
class XiaoZhiConfig {
  const XiaoZhiConfig({
    this.webSocketUrl = 'wss://api.tenclass.net/xiaozhi/v1/',
    this.qtaUrl = 'https://api.tenclass.net/xiaozhi/ota/',
    this.transportType = TransportType.mqtt,
  });

  final String webSocketUrl;
  final String qtaUrl;
  final TransportType transportType;
}

// Ported from Android Kotlin: ServerFormData.kt
class SelfHostConfig {
  const SelfHostConfig({
    this.webSocketUrl = 'ws://192.168.1.246:8000',
    this.transportType = TransportType.webSockets,
  });

  final String webSocketUrl;
  final TransportType transportType;
}

// Ported from Android Kotlin: ServerFormData.kt
enum TransportType {
  mqtt,
  webSockets,
}

// Ported from Android Kotlin: ValidationResult.kt
class ValidationResult {
  const ValidationResult({
    required this.isValid,
    this.errors = const <String, String>{},
  });

  final bool isValid;
  final Map<String, String> errors;
}
