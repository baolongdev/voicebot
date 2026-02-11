// Ported from Android Kotlin: Ota.kt
import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:voicebot/core/system/ota/model/device_info.dart';
import 'package:voicebot/core/system/ota/model/ota_result.dart';
import 'package:voicebot/core/logging/app_logger.dart';
import 'package:voicebot/system/ota/ota_android.dart';
import 'package:voicebot/system/ota/ota_platform.dart';
import 'package:voicebot/system/ota/upgrade_state.dart';

class OtaClient {
  OtaClient(
    DeviceInfo deviceInfo, {
    OtaPlatform? platform,
  })  : _deviceInfo = deviceInfo,
        _platform = platform ?? _resolvePlatform(),
        _client = _createClient() {
    _setHeader('User-Agent', _userAgent);
    _setHeader('Accept-Language', _acceptLanguage);
    _setHeader('X-Language', _acceptLanguage);
    _upgradeStateController.add(const UpgradeState(progress: 0, speed: 0));
  }

  static const String _tag = 'OTA';

  DeviceInfo _deviceInfo;
  final OtaPlatform _platform;
  final http.Client _client;
  final Map<String, String> _headers = <String, String>{};
  final StreamController<UpgradeState> _upgradeStateController =
      StreamController<UpgradeState>.broadcast();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  OtaResult? otaResult;

  DeviceInfo get deviceInfo => _deviceInfo;

  String get currentVersion => _deviceInfo.application.version;

  String get firmwareUrl => otaResult?.firmware?.url ?? '';

  bool get hasActivationCode => otaResult?.activation != null;

  String get _acceptLanguage => 'zh-CN';

  String get _userAgent => 'xingzhi-cube-1.54tft-wifi/1.0.1';

  Stream<UpgradeState> get upgradeState => _upgradeStateController.stream;

  void setHeader(String key, String value) {
    _setHeader(key, value);
  }

  Future<bool> checkVersion(String checkVersionUrl) async {
    _logMessage('Current version: $currentVersion');

    if (checkVersionUrl.length < 10) {
      _logMessage('Check version URL is not properly set');
      return false;
    }

    try {
      otaResult = null;
      final uri = Uri.parse(checkVersionUrl);
      final identity = await _loadOrCreateIdentity();
      _setHeader('Device-Id', identity.macAddress);
      _setHeader('Client-Id', identity.uuid);
      final payload = jsonEncode(_buildOtaPayload(identity));
      final request = payload.isNotEmpty
          ? http.Request('POST', uri)
          : http.Request('GET', uri);
      request.headers.addAll(_headers);
      request.headers['Content-Type'] = 'application/json';
      if (payload.isNotEmpty) {
        request.body = payload;
      }
      final prettyPayload = _prettyJson(payload);
      _logMessage(
        '=== OTA REQUEST ===\nHeaders: ${request.headers}\nPayload:\n$prettyPayload',
      );

      _logMessage('Sending OTA request to $uri');
      final response = await _client.send(request);
      _logMessage('OTA response received: ${response.statusCode}');
      final body = await response.stream.bytesToString();

      _logMessage(
        '=== OTA RESPONSE ===\nStatus: ${response.statusCode}\nBody:\n${_prettyJson(body)}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        _logMessage('Failed to open HTTP connection: ${response.statusCode}');
        return false;
      }

      if (body.isEmpty) {
        _logMessage('Empty response body');
        return false;
      }

      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        _parseJsonResponse(json);
        return true;
      } catch (e, st) {
        _logMessage('Failed to parse OTA response: $e');
        dev.log('Failed to parse OTA response: $e', name: _tag, stackTrace: st);
        return false;
      }
    } catch (e, st) {
      _logMessage('HTTP request failed: $e');
      dev.log('HTTP request failed: $e', name: _tag, stackTrace: st);
      return false;
    }
  }

  Future<void> markCurrentVersionValid() async {
    dev.log('Marking current version as valid (Android simulation)', name: _tag);
  }

  Future<void> upgrade([String? url]) async {
    final firmwareUrl = url ?? this.firmwareUrl;
    dev.log('Upgrading firmware from $firmwareUrl', name: _tag);

    final request = http.Request('GET', Uri.parse(firmwareUrl));

    try {
      final response = await _client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        dev.log('Failed to download firmware: ${response.statusCode}', name: _tag);
        return;
      }

      final contentLength = response.contentLength ?? 0;
      if (contentLength == 0) {
        dev.log('Failed to get content length', name: _tag);
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath =
          '${tempDir.path}${Platform.pathSeparator}firmware.apk';
      final file = File(filePath);
      final sink = file.openWrite();

      var totalRead = 0;
      var recentRead = 0;
      var lastCalcTime = DateTime.now().millisecondsSinceEpoch;
      final buffer = <int>[];

      await for (final chunk in response.stream) {
        buffer.addAll(chunk);
        while (buffer.length >= 512) {
          final data = buffer.sublist(0, 512);
          buffer.removeRange(0, 512);
          sink.add(data);
          final read = data.length;
          totalRead += read;
          recentRead += read;
          _emitProgressIfNeeded(
            totalRead: totalRead,
            recentRead: recentRead,
            contentLength: contentLength,
            lastCalcTime: lastCalcTime,
          );
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - lastCalcTime >= 1000) {
            lastCalcTime = now;
            recentRead = 0;
          }
        }
      }

      if (buffer.isNotEmpty) {
        sink.add(buffer);
        totalRead += buffer.length;
        recentRead += buffer.length;
        _emitProgressIfNeeded(
          totalRead: totalRead,
          recentRead: recentRead,
          contentLength: contentLength,
          lastCalcTime: lastCalcTime,
        );
      }

      await sink.flush();
      await sink.close();

      const downloadedVersion = '1.0.0';
      if (downloadedVersion == currentVersion) {
      dev.log('Firmware version is the same, skipping upgrade', name: _tag);
        return;
      }

      await _platform.installFirmware(file);
      dev.log('Firmware upgrade successful, restarting app...', name: _tag);
      await Future<void>.delayed(const Duration(seconds: 3));
      await _platform.restartApp();
    } catch (e) {
      dev.log('Upgrade failed: $e', name: _tag);
    }
  }

  Future<void> startUpgrade() async {
    await upgrade(firmwareUrl);
  }

  List<int> _parseVersion(String version) {
    return version.split('.').map(int.parse).toList();
  }

  // ignore: unused_element
  bool _isNewVersionAvailable(String currentVersion, String newVersion) {
    final current = _parseVersion(currentVersion);
    final newer = _parseVersion(newVersion);

    final count = current.length < newer.length ? current.length : newer.length;
    for (var i = 0; i < count; i++) {
      if (newer[i] > current[i]) return true;
      if (newer[i] < current[i]) return false;
    }
    return newer.length > current.length;
  }

  void _parseJsonResponse(Map<String, dynamic> json) {
    otaResult = fromJsonToOtaResult(json);
  }

  Map<String, dynamic> _buildOtaPayload(_DeviceIdentity identity) {
    return <String, dynamic>{
      'application': <String, dynamic>{
        'name': 'xiaozhi',
        'version': '1.0.1',
        'elf_sha256': _stableElfSha256,
      },
      'mac_address': identity.macAddress,
      'uuid': identity.uuid,
      'board': <String, dynamic>{
        'type': 'xingzhi-cube-1.54tft-wifi',
        'name': 'xingzhi-cube-1.54tft-wifi',
        'ssid': 'XiaoZhi',
        'rssi': -40,
      },
    };
  }

  String get _stableElfSha256 =>
      '0000000000000000000000000000000000000000000000000000000000000000';

  String _normalizeMac(String input) {
    final hex = input.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toLowerCase();
    if (hex.length != 12) {
      return input.toLowerCase();
    }
    final buffer = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      if (i > 0) {
        buffer.write(':');
      }
      buffer.write(hex.substring(i, i + 2));
    }
    return buffer.toString();
  }

  bool _isInvalidMac(String macAddress) {
    final normalized = _normalizeMac(macAddress);
    return normalized == '02:00:00:00:00:00' ||
        normalized == '00:00:00:00:00:00';
  }

  Future<_DeviceIdentity> _loadOrCreateIdentity() async {
    const macKey = 'ota_device_mac';
    const uuidKey = 'ota_device_uuid';
    final platformMac = await _platform.getMacAddress();
    final deviceId = await _platform.getDeviceId();
    if (platformMac != null &&
        platformMac.isNotEmpty &&
        !_isInvalidMac(platformMac)) {
      final normalizedMac = _normalizeMac(platformMac);
      final uuid = (deviceId != null && deviceId.isNotEmpty)
          ? _uuidFromDeviceId(deviceId)
          : _uuidFromDeviceId(normalizedMac);
      final identity = _DeviceIdentity(
        macAddress: normalizedMac,
        uuid: uuid,
      );
      await _storage.write(key: macKey, value: normalizedMac);
      await _storage.write(key: uuidKey, value: uuid);
      _syncDeviceInfo(identity);
      return identity;
    }
    if (deviceId != null && deviceId.isNotEmpty) {
      final identity = _DeviceIdentity(
        macAddress: _macFromDeviceId(deviceId),
        uuid: _uuidFromDeviceId(deviceId),
      );
      _syncDeviceInfo(identity);
      return identity;
    }
    final storedMac = await _storage.read(key: macKey);
    final storedUuid = await _storage.read(key: uuidKey);
    if (storedMac != null && storedUuid != null) {
      final identity = _DeviceIdentity(
        macAddress: _normalizeMac(storedMac),
        uuid: storedUuid,
      );
      _syncDeviceInfo(identity);
      return identity;
    }

    final uuid = _generateUuidV4(Random());
    final macAddress = _normalizeMac(_macFromDeviceId(uuid));
    await _storage.write(key: macKey, value: macAddress);
    await _storage.write(key: uuidKey, value: uuid);
    final identity = _DeviceIdentity(macAddress: macAddress, uuid: uuid);
    _syncDeviceInfo(identity);
    return identity;
  }

  String _generateUuidV4(Random random) {
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String byteToHex(int value) => value.toRadixString(16).padLeft(2, '0');
    final parts = <String>[
      bytes.sublist(0, 4).map(byteToHex).join(),
      bytes.sublist(4, 6).map(byteToHex).join(),
      bytes.sublist(6, 8).map(byteToHex).join(),
      bytes.sublist(8, 10).map(byteToHex).join(),
      bytes.sublist(10, 16).map(byteToHex).join(),
    ];
    return parts.join('-');
  }

  String _macFromDeviceId(String deviceId) {
    final bytes = _fnv1a64(deviceId);
    final macBytes = List<int>.filled(6, 0);
    for (var i = 0; i < 6; i++) {
      macBytes[i] = (bytes >> (i * 8)) & 0xff;
    }
    // Locally administered, unicast.
    macBytes[0] = (macBytes[0] & 0xfe) | 0x02;
    final buffer = StringBuffer();
    for (var i = 0; i < macBytes.length; i++) {
      if (i > 0) {
        buffer.write(':');
      }
      buffer.write(macBytes[i].toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  int _fnv1a64(String input) {
    const int fnvOffset = 0xcbf29ce484222325;
    const int fnvPrime = 0x100000001b3;
    var hash = fnvOffset;
    for (final codeUnit in input.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash;
  }

  String _uuidFromDeviceId(String deviceId) {
    final hashA = _fnv1a64(deviceId);
    final hashB = _fnv1a64('$deviceId:voicebot');
    final bytes = Uint8List(16);
    for (var i = 0; i < 8; i++) {
      bytes[i] = (hashA >> (i * 8)) & 0xff;
      bytes[8 + i] = (hashB >> (i * 8)) & 0xff;
    }
    // Set UUID v4 variant/version bits.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String toHex(int value) => value.toRadixString(16).padLeft(2, '0');
    final parts = <String>[
      bytes.sublist(0, 4).map(toHex).join(),
      bytes.sublist(4, 6).map(toHex).join(),
      bytes.sublist(6, 8).map(toHex).join(),
      bytes.sublist(8, 10).map(toHex).join(),
      bytes.sublist(10, 16).map(toHex).join(),
    ];
    return parts.join('-');
  }

  String _prettyJson(String value) {
    try {
      final decoded = jsonDecode(value);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(decoded);
    } catch (_) {
      return value;
    }
  }

  void _setHeader(String key, String value) {
    _headers[key] = value;
  }

  void _emitProgressIfNeeded({
    required int totalRead,
    required int recentRead,
    required int contentLength,
    required int lastCalcTime,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastCalcTime >= 1000 || recentRead == 0) {
      final progress = (totalRead * 100 ~/ contentLength);
      final speed = recentRead == 0
          ? 0
          : (recentRead * 1000 ~/ (now - lastCalcTime));
      dev.log(
        'Progress: $progress% ($totalRead/$contentLength), '
        'Speed: $speed B/s',
        name: _tag,
      );
      _upgradeStateController.add(
        UpgradeState(progress: progress, speed: speed),
      );
    }
  }

  static http.Client _createClient() {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10)
      ..idleTimeout = const Duration(seconds: 30);
    return IOClient(httpClient);
  }

  static OtaPlatform _resolvePlatform() {
    if (!kIsWeb && Platform.isAndroid) {
      return const OtaAndroidPlatform();
    }
    return const OtaNoopPlatform();
  }

  void _logMessage(String message) {
    // Keep logs visible in release while preserving dev tools logs.
    AppLogger.log('Ota', message);
    dev.log(message, name: _tag);
  }

  void _syncDeviceInfo(_DeviceIdentity identity) {
    _deviceInfo = DeviceInfo(
      version: _deviceInfo.version,
      flashSize: _deviceInfo.flashSize,
      psramSize: _deviceInfo.psramSize,
      minimumFreeHeapSize: _deviceInfo.minimumFreeHeapSize,
      macAddress: identity.macAddress,
      uuid: identity.uuid,
      chipModelName: _deviceInfo.chipModelName,
      chipInfo: _deviceInfo.chipInfo,
      application: _deviceInfo.application,
      partitionTable: _deviceInfo.partitionTable,
      ota: _deviceInfo.ota,
      board: _deviceInfo.board,
    );
  }
}

class _DeviceIdentity {
  const _DeviceIdentity({
    required this.macAddress,
    required this.uuid,
  });

  final String macAddress;
  final String uuid;
}
