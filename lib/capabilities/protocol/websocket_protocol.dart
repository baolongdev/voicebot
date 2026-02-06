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
  StreamSubscription? _websocketSubscription;
  Completer<bool> _helloReceived = Completer<bool>();
  int _connectionEpoch = 0;
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
    _connectionEpoch += 1;
    _isOpen = false;
    _websocketSubscription?.cancel();
    _websocketSubscription = null;
    final socket = _websocket;
    _websocket = null;
    socket?.close(1000, 'Normal closure');
  }

  @override
  Future<bool> openAudioChannel() async {
    closeAudioChannel();
    _helloReceived = Completer<bool>();
    final epoch = _connectionEpoch;

    AppLogger.event(
      'WS',
      'connect_start',
      fields: <String, Object?>{
        'url': url,
        'device_id': deviceInfo.macAddress.toLowerCase(),
        'client_id': deviceInfo.uuid,
      },
    );
    final headers = <String, String>{
      'Authorization': 'Bearer $accessToken',
      'Protocol-Version': '1',
      'Device-Id': deviceInfo.macAddress.toLowerCase(),
      'Client-Id': deviceInfo.uuid,
    };

    try {
      _websocket = await WebSocket.connect(url, headers: headers);
    } catch (_) {
      if (!networkErrorStream.isClosed) {
        networkErrorStream.add('Server not found');
      }
      return false;
    }

    AppLogger.event(
      'WS',
      'connect_success',
      fields: <String, Object?>{
        'url': url,
      },
    );
    _isOpen = true;
    if (!audioChannelStateStream.isClosed) {
      audioChannelStateStream.add(AudioState.opened);
    }

    final helloMessage = <String, dynamic>{
      'type': 'hello',
      'version': 1,
      'transport': 'websocket',
      'features': <String, dynamic>{
        'mcp': true,
      },
      'audio_params': <String, dynamic>{
        'format': 'opus',
        'sample_rate': AudioConfig.sampleRate,
        'channels': AudioConfig.channels,
        'frame_duration': AudioConfig.frameDurationMs,
      },
    };
    AppLogger.event(
      'WS',
      'hello_send',
      fields: <String, Object?>{
        'audio_format': 'opus',
        'sample_rate': AudioConfig.sampleRate,
        'channels': AudioConfig.channels,
        'frame_ms': AudioConfig.frameDurationMs,
      },
    );
    await sendText(jsonEncode(helloMessage));
    AppLogger.event('WS', 'hello_sent');

    StreamSubscription? subscription;
    subscription = _websocket?.listen(
      (event) {
        if (epoch != _connectionEpoch) {
          return;
        }
        if (event is String) {
          Map<String, dynamic>? json;
          try {
            final decoded = jsonDecode(event);
            if (decoded is Map<String, dynamic>) {
              json = decoded;
            }
          } catch (_) {
            // Emit error instead of throwing inside listener.
            if (!networkErrorStream.isClosed) {
              networkErrorStream.add('Invalid JSON');
            }
            return;
          }
          if (json == null) {
            if (!networkErrorStream.isClosed) {
              networkErrorStream.add('Invalid JSON');
            }
            return;
          }
          _logMessage('WebSocket message: ${jsonEncode(json)}');
          final type = json['type'] as String? ?? '';
          if (type == 'hello') {
            _parseServerHello(json);
          } else {
            if (!incomingJsonStream.isClosed) {
              incomingJsonStream.add(json);
            }
          }
        } else if (event is List<int>) {
          if (!incomingAudioStream.isClosed) {
            incomingAudioStream.add(Uint8List.fromList(event));
          }
        }
      },
      onError: (error) async {
        if (epoch != _connectionEpoch) {
          return;
        }
        _isOpen = false;
        _logMessage('socket error');
        if (!networkErrorStream.isClosed) {
          networkErrorStream.add('Server not found');
        }
        _websocket = null;
        if (_websocketSubscription == subscription) {
          _websocketSubscription = null;
        }
      },
      onDone: () async {
        if (epoch != _connectionEpoch) {
          return;
        }
        _isOpen = false;
        final code = _websocket?.closeCode;
        final reason = _websocket?.closeReason;
        AppLogger.event(
          'WS',
          'socket_closed',
          fields: <String, Object?>{
            'code': code?.toString(),
            'reason': reason,
          },
        );
        if (!networkErrorStream.isClosed) {
          networkErrorStream.add('Socket closed');
        }
        if (!audioChannelStateStream.isClosed) {
          audioChannelStateStream.add(AudioState.closed);
        }
        _websocket = null;
        if (_websocketSubscription == subscription) {
          _websocketSubscription = null;
        }
      },
      cancelOnError: true,
    );
    if (subscription != null) {
      _websocketSubscription = subscription;
    }

    try {
      AppLogger.event('WS', 'hello_wait');
      return await _helloReceived.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          AppLogger.event('WS', 'hello_timeout');
          if (!networkErrorStream.isClosed) {
            networkErrorStream.add('Server timeout');
          }
          closeAudioChannel();
          return false;
        },
      );
    } catch (_) {
      AppLogger.event('WS', 'hello_timeout');
      if (!networkErrorStream.isClosed) {
        networkErrorStream.add('Server timeout');
      }
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
    AppLogger.event(
      'WS',
      'hello_received',
      fields: <String, Object?>{
        'session_id': sessionId,
        'sample_rate': _serverSampleRate,
      },
    );

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
