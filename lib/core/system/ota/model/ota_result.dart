import 'dart:convert';

// Ported from Android Kotlin: OtaResult.kt
class OtaResult {
  const OtaResult({
    required this.mqttConfig,
    required this.websocket,
    required this.activation,
    required this.serverTime,
    required this.firmware,
  });

  final MqttConfig mqttConfig;
  final WebsocketConfig? websocket;
  final Activation? activation;
  final ServerTime? serverTime;
  final Firmware? firmware;

  factory OtaResult.fromJson(Map<String, dynamic> json) {
    return OtaResult(
      mqttConfig: fromJsonToMqttConfig(json['mqtt'] as Map<String, dynamic>),
      websocket: json['websocket'] == null
          ? null
          : fromJsonToWebsocketConfig(
              json['websocket'] as Map<String, dynamic>,
            ),
      activation: json['activation'] == null
          ? null
          : fromJsonToActivation(json['activation'] as Map<String, dynamic>),
      serverTime: json['server_time'] == null
          ? null
          : fromJsonToServerTime(
              json['server_time'] as Map<String, dynamic>,
            ),
      firmware: json['firmware'] == null
          ? null
          : fromJsonToFirmware(json['firmware'] as Map<String, dynamic>),
    );
  }
}

// Ported from Android Kotlin: OtaResult.kt
OtaResult fromJsonToOtaResult(Map<String, dynamic> json) {
  return OtaResult.fromJson(json);
}

// Ported from Android Kotlin: OtaResult.kt
OtaResult fromJsonStringToOtaResult(String json) {
  final obj = jsonDecode(json) as Map<String, dynamic>;
  return OtaResult.fromJson(obj);
}

// Ported from Android Kotlin: OtaResult.kt
class ServerTime {
  const ServerTime({
    required this.timestamp,
    required this.timezone,
    required this.timezoneOffset,
  });

  final int timestamp;
  final String? timezone;
  final int timezoneOffset;

  factory ServerTime.fromJson(Map<String, dynamic> json) {
    return ServerTime(
      timestamp: (json['timestamp'] as num).toInt(),
      timezone: json.containsKey('timezone') ? json['timezone'] as String? : null,
      timezoneOffset: json['timezone_offset'] as int,
    );
  }
}

// Ported from Android Kotlin: OtaResult.kt
ServerTime fromJsonToServerTime(Map<String, dynamic> json) {
  return ServerTime.fromJson(json);
}

// Ported from Android Kotlin: OtaResult.kt
class Firmware {
  const Firmware({
    required this.version,
    required this.url,
  });

  final String version;
  final String url;

  factory Firmware.fromJson(Map<String, dynamic> json) {
    return Firmware(
      version: json['version'] as String,
      url: json['url'] as String,
    );
  }
}

// Ported from Android Kotlin: OtaResult.kt
Firmware fromJsonToFirmware(Map<String, dynamic> json) {
  return Firmware.fromJson(json);
}

// Ported from Android Kotlin: OtaResult.kt
class Activation {
  const Activation({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;

  factory Activation.fromJson(Map<String, dynamic> json) {
    return Activation(
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }
}

// Ported from Android Kotlin: OtaResult.kt
Activation fromJsonToActivation(Map<String, dynamic> json) {
  return Activation.fromJson(json);
}

// Ported from Android Kotlin: OtaResult.kt
class MqttConfig {
  const MqttConfig({
    required this.endpoint,
    required this.clientId,
    required this.username,
    required this.password,
    required this.publishTopic,
    required this.subscribeTopic,
  });

  final String endpoint;
  final String clientId;
  final String username;
  final String password;
  final String publishTopic;
  final String subscribeTopic;

  factory MqttConfig.fromJson(Map<String, dynamic> json) {
    return MqttConfig(
      endpoint: json['endpoint'] as String,
      clientId: json['client_id'] as String,
      username: json['username'] as String,
      password: json['password'] as String,
      publishTopic: json['publish_topic'] as String,
      subscribeTopic: json['subscribe_topic'] as String,
    );
  }
}

// Ported from Android Kotlin: OtaResult.kt
MqttConfig fromJsonToMqttConfig(Map<String, dynamic> json) {
  return MqttConfig.fromJson(json);
}

// Ported from Android Kotlin: OtaResult.kt
class WebsocketConfig {
  const WebsocketConfig({
    required this.url,
    required this.token,
  });

  final String url;
  final String token;

  factory WebsocketConfig.fromJson(Map<String, dynamic> json) {
    return WebsocketConfig(
      url: json['url'] as String? ?? '',
      token: json['token'] as String? ?? '',
    );
  }
}

// Ported from Android Kotlin: OtaResult.kt
WebsocketConfig fromJsonToWebsocketConfig(Map<String, dynamic> json) {
  return WebsocketConfig.fromJson(json);
}
