import 'dart:async';
import 'dart:convert';

import 'package:voicebot/core/system/ota/model/ota_result.dart';
import '../../domain/models/server_form_data.dart';
import 'settings_repository.dart';
import 'settings_storage.dart';

// Ported from Android Kotlin: SettingsRepository.kt
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._storage);

  final SettingsStorage _storage;
  bool _hydrated = false;

  static const String _transportKey = 'settings_transport_type';
  static const String _mqttKey = 'settings_mqtt_config';
  static const String _wsUrlKey = 'settings_ws_url';
  static const String _wsTokenKey = 'settings_ws_token';

  TransportType _transportType = TransportType.mqtt;
  MqttConfig? _mqttConfig;
  String? _webSocketUrl;
  String? _webSocketToken;

  @override
  Future<void> hydrate() async {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    final transportValue = await _storage.read(_transportKey);
    if (transportValue != null && transportValue.isNotEmpty) {
      transportType = _parseTransportType(transportValue);
    }
    final mqttValue = await _storage.read(_mqttKey);
    if (mqttValue != null && mqttValue.isNotEmpty) {
      try {
        final json = jsonDecode(mqttValue) as Map<String, dynamic>;
        mqttConfig = fromJsonToMqttConfig(json);
      } catch (_) {
        mqttConfig = null;
      }
    }
    webSocketUrl = await _storage.read(_wsUrlKey);
    webSocketToken = await _storage.read(_wsTokenKey);
  }

  @override
  TransportType get transportType => _transportType;

  @override
  set transportType(TransportType value) {
    _transportType = value;
    unawaited(_storage.write(_transportKey, value.name));
  }

  @override
  MqttConfig? get mqttConfig => _mqttConfig;

  @override
  set mqttConfig(MqttConfig? value) {
    _mqttConfig = value;
    if (value == null) {
      unawaited(_storage.delete(_mqttKey));
      return;
    }
    final json = jsonEncode(_mqttConfigToJson(value));
    unawaited(_storage.write(_mqttKey, json));
  }

  @override
  String? get webSocketUrl => _webSocketUrl;

  @override
  set webSocketUrl(String? value) {
    _webSocketUrl = value;
    if (value == null || value.isEmpty) {
      unawaited(_storage.delete(_wsUrlKey));
      return;
    }
    unawaited(_storage.write(_wsUrlKey, value));
  }

  @override
  String? get webSocketToken => _webSocketToken;

  @override
  set webSocketToken(String? value) {
    _webSocketToken = value;
    if (value == null || value.isEmpty) {
      unawaited(_storage.delete(_wsTokenKey));
      return;
    }
    unawaited(_storage.write(_wsTokenKey, value));
  }

  @override
  bool get hasValidWebSocketConfig {
    final url = _webSocketUrl ?? '';
    final token = _webSocketToken ?? '';
    return url.isNotEmpty && token.isNotEmpty;
  }

  @override
  bool get hasValidMqttConfig => _isValidMqttConfig(_mqttConfig);

  @override
  void applyOtaResult(OtaResult result) {
    mqttConfig = result.mqttConfig;
    final websocket = result.websocket;
    if (websocket != null) {
      if (websocket.url.isNotEmpty) {
        webSocketUrl = websocket.url;
      }
      if (websocket.token.isNotEmpty) {
        webSocketToken = websocket.token;
      }
    }
    _selectTransport(websocket: websocket, mqtt: result.mqttConfig);
  }

  @override
  void normalizeTransport() {
    final hasWs = hasValidWebSocketConfig;
    final hasMqtt = hasValidMqttConfig;
    if (transportType == TransportType.webSockets && !hasWs && hasMqtt) {
      transportType = TransportType.mqtt;
      return;
    }
    if (transportType == TransportType.mqtt && !hasMqtt && hasWs) {
      transportType = TransportType.webSockets;
    }
  }

  Map<String, dynamic> _mqttConfigToJson(MqttConfig config) {
    return <String, dynamic>{
      'endpoint': config.endpoint,
      'client_id': config.clientId,
      'username': config.username,
      'password': config.password,
      'publish_topic': config.publishTopic,
      'subscribe_topic': config.subscribeTopic,
    };
  }

  TransportType _parseTransportType(String value) {
    for (final type in TransportType.values) {
      if (type.name == value) {
        return type;
      }
    }
    return TransportType.mqtt;
  }

  void _selectTransport({
    required WebsocketConfig? websocket,
    required MqttConfig? mqtt,
  }) {
    final hasWs = websocket != null &&
        websocket.url.isNotEmpty &&
        websocket.token.isNotEmpty;
    final hasMqtt = _isValidMqttConfig(mqtt);
    if (hasWs) {
      transportType = TransportType.webSockets;
      return;
    }
    if (hasMqtt) {
      transportType = TransportType.mqtt;
    }
  }

  bool _isValidMqttConfig(MqttConfig? config) {
    if (config == null) {
      return false;
    }
    return config.endpoint.isNotEmpty &&
        config.clientId.isNotEmpty &&
        config.publishTopic.isNotEmpty &&
        config.subscribeTopic.isNotEmpty;
  }
}
