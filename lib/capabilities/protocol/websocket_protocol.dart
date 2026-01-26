import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../core/audio/audio_config.dart';
import '../../core/logging/app_logger.dart';
import '../../core/system/ota/model/device_info.dart';
import 'protocol.dart';

// Ported from Android Kotlin: WebsocketProtocol.kt
class WebsocketProtocol extends Protocol {
  WebsocketProtocol({
    required this.deviceInfo,
    required this.url,
    required this.accessToken,
  });

  final DeviceInfo deviceInfo;
  final String url;
  final String accessToken;

  bool _isOpen = false;
  WebSocket? _websocket;
  Completer<bool> _helloReceived = Completer<bool>();
  // Keep parity with Android; used for diagnostics even if unused in Dart.
  // ignore: unused_field
  int _serverSampleRate = -1;
  int get serverSampleRate => _serverSampleRate;

  @override
  Future<void> start() async {
    // no-op, parity with Android
  }

  @override
  Future<void> sendAudio(Uint8List data) async {
    _websocket?.add(data);
  }

  @override
  Future<void> sendText(String text) async {
    _websocket?.add(text);
  }

  @override
  bool isAudioChannelOpened() => _websocket != null && _isOpen;

  @override
  void closeAudioChannel() {
    _websocket?.close(1000, 'Normal closure');
    _websocket = null;
  }

  @override
  Future<bool> openAudioChannel() async {
    closeAudioChannel();
    _helloReceived = Completer<bool>();

    _logMessage('WebSocket connecting to $url');
    _logMessage('Header: Authorization: Bearer $accessToken');
    _logMessage('Header: Protocol-Version: 1');
    _logMessage('Header: Device-Id: ${deviceInfo.macAddress.toLowerCase()}');
    _logMessage('Header: Client-Id: ${deviceInfo.uuid}');
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Protocol-Version': '1',
      'Device-Id': deviceInfo.macAddress.toLowerCase(),
      'Client-Id': deviceInfo.uuid,
    };

    try {
      _websocket = await WebSocket.connect(url, headers: headers);
    } catch (_) {
      networkErrorStream.add('Server not found');
      return false;
    }

    _logMessage('WebSocket connected');
    _isOpen = true;
    audioChannelStateStream.add(AudioState.opened);

    final helloMessage = <String, dynamic>{
      'type': 'hello',
      'version': 1,
      'transport': 'websocket',
      'audio_params': <String, dynamic>{
        'format': 'opus',
        'sample_rate': AudioConfig.sampleRate,
        'channels': AudioConfig.channels,
        'frame_duration': AudioConfig.frameDurationMs,
      },
    };
    _logMessage('WebSocket hello: ${jsonEncode(helloMessage)}');
    await sendText(jsonEncode(helloMessage));
    _logMessage('hello sent');

    _websocket?.listen(
      (event) {
        if (event is String) {
          Map<String, dynamic>? json;
          try {
            final decoded = jsonDecode(event);
            if (decoded is Map<String, dynamic>) {
              json = decoded;
            }
          } catch (_) {
            // Emit error instead of throwing inside listener.
            networkErrorStream.add('Invalid JSON');
            return;
          }
          if (json == null) {
            networkErrorStream.add('Invalid JSON');
            return;
          }
          _logMessage('WebSocket message: ${jsonEncode(json)}');
          final type = json['type'] as String? ?? '';
          if (type == 'hello') {
            _parseServerHello(json);
          } else {
            incomingJsonStream.add(json);
          }
        } else if (event is List<int>) {
          incomingAudioStream.add(Uint8List.fromList(event));
        }
      },
      onError: (error) async {
        _isOpen = false;
        _logMessage('socket error');
        networkErrorStream.add('Server not found');
        _websocket = null;
      },
      onDone: () async {
        _isOpen = false;
        final code = _websocket?.closeCode;
        final reason = _websocket?.closeReason;
        _logMessage(
          'socket closed code=${code ?? '-'} reason=${reason ?? '-'}',
        );
        audioChannelStateStream.add(AudioState.closed);
        _websocket = null;
      },
    );

    try {
      _logMessage('Waiting for server hello');
      return await _helloReceived.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          _logMessage('hello timeout');
          networkErrorStream.add('Server timeout');
          closeAudioChannel();
          return false;
        },
      );
    } catch (_) {
      _logMessage('hello timeout');
      networkErrorStream.add('Server timeout');
      closeAudioChannel();
      return false;
    }
  }

  void _parseServerHello(Map<String, dynamic> root) {
    final transport = root['transport'] as String? ?? '';
    if (transport != 'websocket') {
      return;
    }

    final audioParams = root['audio_params'] as Map<String, dynamic>?;
    if (audioParams != null) {
      final sampleRate = audioParams['sample_rate'] as int? ?? -1;
      if (sampleRate != -1) {
        _serverSampleRate = sampleRate;
      }
    }
    sessionId = root['session_id'] as String? ?? '';
    _logMessage('hello received');

    if (!_helloReceived.isCompleted) {
      _helloReceived.complete(true);
    }
  }

  @override
  void dispose() {
    closeAudioChannel();
    incomingJsonStream.close();
    incomingAudioStream.close();
    audioChannelStateStream.close();
    networkErrorStream.close();
  }

  void _logMessage(String message) {
    AppLogger.log('WS', message);
  }
}
