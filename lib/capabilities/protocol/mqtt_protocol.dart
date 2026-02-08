import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:pointycastle/export.dart';
import 'package:synchronized/synchronized.dart';

import '../../core/audio/audio_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/system/ota/model/ota_result.dart';
import 'protocol.dart';
import 'udp_client.dart';

// Ported from Android Kotlin: MqttProtocol.kt
class MqttProtocol extends Protocol {
  MqttProtocol({required this.mqttConfig}) : _mutex = Lock();

  final MqttConfig mqttConfig;
  final Lock _mutex;

  MqttServerClient? _client;
  UdpClient? _udpClient;

  String _endpoint = '';
  String _clientId = '';
  String _username = '';
  String _password = '';
  String _publishTopic = '';

  late Uint8List _aesKey;
  Uint8List _aesNonce = Uint8List(16);
  int _localSequence = 0;
  int _remoteSequence = 0;

  @override
  Future<void> start() async {
    await _startMqttClient();
  }

  Future<void> _startMqttClient() async {
    if (_client?.connectionStatus?.state ==
        mqtt.MqttConnectionState.connected) {
      _client?.disconnect();
    }

    _endpoint = 'tcp://${mqttConfig.endpoint}';
    _clientId = mqttConfig.clientId;
    _username = mqttConfig.username;
    _password = mqttConfig.password;
    _publishTopic = mqttConfig.publishTopic;

    if (_endpoint.isEmpty) {
      networkErrorStream.add('Server not found');
      return;
    }

    AppLogger.event(
      'MQTT',
      'connect_start',
      fields: <String, Object?>{'endpoint': _endpoint},
    );

    final client = MqttServerClient(_endpoint, _clientId)
      ..keepAlivePeriod = 90
      ..autoReconnect = true
      ..onDisconnected = () {
        networkErrorStream.add('Connection lost');
      }
      ..onConnected = () {
        // no-op, parity with Android log
      }
      ..logging(on: false)
      ..connectionMessage = mqtt.MqttConnectMessage()
          .withClientIdentifier(_clientId)
          .authenticateAs(_username, _password)
          .withWillQos(mqtt.MqttQos.atLeastOnce);

    client.updates?.listen((events) async {
      for (final event in events) {
        final payload =
            (event.payload as mqtt.MqttPublishMessage).payload.message;
        final text = mqtt.MqttPublishPayload.bytesToStringAsString(payload);
        Map<String, dynamic>? json;
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map<String, dynamic>) {
            json = decoded;
          }
        } catch (error) {
          AppLogger.event(
            'MQTT',
            'invalid_json',
            fields: <String, Object?>{'error': error.toString()},
            level: 'W',
          );
          // Emit error instead of throwing inside listener.
          networkErrorStream.add('Invalid JSON');
          continue;
        }
        if (json == null) {
          networkErrorStream.add('Invalid JSON');
          continue;
        }
        switch (json['type'] as String? ?? '') {
          case 'hello':
            await _parseServerHello(json);
          case 'goodbye':
            final sid = json['session_id'] as String? ?? '';
            if (sid.isEmpty || sid == sessionId) {
              closeAudioChannel();
            }
          default:
            incomingJsonStream.add(json);
        }
      }
    });

    _client = client;

    try {
      await client.connect();
    } catch (error) {
      AppLogger.event(
        'MQTT',
        'connect_failed',
        fields: <String, Object?>{
          'endpoint': _endpoint,
          'error': error.toString(),
        },
        level: 'E',
      );
      networkErrorStream.add('Server not connected');
      return;
    }
  }

  @override
  Future<void> sendAudio(Uint8List data) async {
    await _mutex.synchronized(() async {
      if (_udpClient == null) {
        return;
      }

      final nonce = Uint8List.fromList(_aesNonce);
      final size = data.length;
      nonce[2] = (size >> 8) & 0xff;
      nonce[3] = size & 0xff;
      final seq = ++_localSequence;
      nonce[12] = (seq >> 24) & 0xff;
      nonce[13] = (seq >> 16) & 0xff;
      nonce[14] = (seq >> 8) & 0xff;
      nonce[15] = seq & 0xff;

      final encrypted = _aesCtrEncrypt(data, nonce);
      final packet = Uint8List(nonce.length + encrypted.length);
      packet.setRange(0, nonce.length, nonce);
      packet.setRange(nonce.length, packet.length, encrypted);
      _udpClient?.send(packet);
    });
  }

  @override
  Future<bool> openAudioChannel() async {
    if (_client?.connectionStatus?.state !=
        mqtt.MqttConnectionState.connected) {
      await _startMqttClient();
      if (_client?.connectionStatus?.state !=
          mqtt.MqttConnectionState.connected) {
        return false;
      }
    }

    sessionId = '';
    final helloMessage = <String, dynamic>{
      'type': 'hello',
      'version': 3,
      'transport': 'udp',
      'features': <String, dynamic>{'mcp': true},
      'audio_params': <String, dynamic>{
        'format': 'opus',
        'sample_rate': AudioConfig.sampleRate,
        'channels': AudioConfig.channels,
        'frame_duration': AudioConfig.frameDurationMs,
      },
    };
    AppLogger.event(
      'MQTT',
      'hello_send',
      fields: <String, Object?>{
        'audio_format': 'opus',
        'sample_rate': AudioConfig.sampleRate,
        'channels': AudioConfig.channels,
        'frame_ms': AudioConfig.frameDurationMs,
      },
    );
    await sendText(jsonEncode(helloMessage));

    final completer = Completer<bool>();
    Timer(const Duration(seconds: 10), () {
      if (sessionId.isEmpty) {
        networkErrorStream.add('Server timeout');
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      } else {
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      }
    });
    return completer.future;
  }

  @override
  void closeAudioChannel() {
    _mutex.synchronized(() {
      _udpClient?.close();
      _udpClient = null;
    });
    () async {
      final goodbyeMessage = <String, dynamic>{
        'session_id': sessionId,
        'type': 'goodbye',
      };
      await sendText(jsonEncode(goodbyeMessage));
      audioChannelStateStream.add(AudioState.closed);
    }();
  }

  @override
  bool isAudioChannelOpened() => _udpClient != null;

  @override
  Future<void> sendText(String text) async {
    if (_publishTopic.isEmpty ||
        _client?.connectionStatus?.state !=
            mqtt.MqttConnectionState.connected) {
      return;
    }
    try {
      final builder = mqtt.MqttClientPayloadBuilder();
      builder.addString(text);
      _client?.publishMessage(
        _publishTopic,
        mqtt.MqttQos.atLeastOnce,
        builder.payload!,
      );
    } catch (error) {
      AppLogger.event(
        'MQTT',
        'publish_failed',
        fields: <String, Object?>{'error': error.toString()},
        level: 'E',
      );
      networkErrorStream.add('Server error');
    }
  }

  Future<void> _parseServerHello(Map<String, dynamic> json) async {
    if ((json['transport'] as String?) != 'udp') {
      networkErrorStream.add('Unsupported transport');
      return;
    }

    sessionId = json['session_id'] as String? ?? '';
    AppLogger.event(
      'MQTT',
      'hello_received',
      fields: <String, Object?>{'session_id': sessionId},
    );

    final udp = json['udp'] as Map<String, dynamic>?;
    if (udp == null) {
      networkErrorStream.add('UDP not specified');
      return;
    }
    final server = udp['server'] as String? ?? '';
    final port = udp['port'] as int? ?? 0;
    final key = _decodeHexString(udp['key'] as String? ?? '');
    _aesNonce = _decodeHexString(udp['nonce'] as String? ?? '');
    _aesKey = key;

    await _mutex.synchronized(() async {
      _udpClient?.close();
      _udpClient = UdpClient(server, port)
        ..setOnMessage((data) {
          _handleUdpPacket(data);
        });
    });
    audioChannelStateStream.add(AudioState.opened);
  }

  void _handleUdpPacket(Uint8List data) {
    if (data.length < _aesNonce.length) {
      return;
    }
    if (data[0] != 1) {
      return;
    }
    final sequence =
        ((data[12] & 0xff) << 24) |
        ((data[13] & 0xff) << 16) |
        ((data[14] & 0xff) << 8) |
        (data[15] & 0xff);
    if (sequence < _remoteSequence) {
      return;
    }
    if (sequence != _remoteSequence + 1) {
      // keep parity with Android log-only
    }

    final nonce = data.sublist(0, _aesNonce.length);
    final encrypted = data.sublist(_aesNonce.length);
    final decrypted = _aesCtrDecrypt(encrypted, nonce);
    incomingAudioStream.add(decrypted);
    _remoteSequence = sequence;
  }

  Uint8List _aesCtrEncrypt(Uint8List data, Uint8List nonce) {
    final cipher = CTRStreamCipher(AESEngine())
      ..init(true, ParametersWithIV(KeyParameter(_aesKey), nonce));
    return cipher.process(data);
  }

  Uint8List _aesCtrDecrypt(Uint8List data, Uint8List nonce) {
    final cipher = CTRStreamCipher(AESEngine())
      ..init(false, ParametersWithIV(KeyParameter(_aesKey), nonce));
    return cipher.process(data);
  }

  Uint8List _decodeHexString(String hex) {
    if (hex.isEmpty) {
      return Uint8List(0);
    }
    final bytes = <int>[];
    for (var i = 0; i < hex.length; i += 2) {
      bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  @override
  void dispose() {
    _client?.disconnect();
    _udpClient?.close();
    incomingJsonStream.close();
    incomingAudioStream.close();
    audioChannelStateStream.close();
    networkErrorStream.close();
  }
}
