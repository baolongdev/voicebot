import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

void main(List<String> args) async {
  final url = _argValue(args, '--url') ??
      'https://api.tenclass.net/xiaozhi/ota/';
  final mac = _argValue(args, '--mac') ?? _generateMac(Random());
  final uuid = _argValue(args, '--uuid') ?? _generateUuidV4(Random());

  final payload = <String, dynamic>{
    'application': <String, dynamic>{
      'name': 'xiaozhi',
      'version': '1.0.1',
      'elf_sha256':
          '0000000000000000000000000000000000000000000000000000000000000000',
    },
    'mac_address': mac,
    'uuid': uuid,
    'board': <String, dynamic>{
      'type': 'xingzhi-cube-1.54tft-wifi',
      'name': 'xingzhi-cube-1.54tft-wifi',
      'ssid': 'XiaoZhi',
      'rssi': -40,
    },
  };

  final headers = <String, String>{
    'User-Agent': 'xingzhi-cube-1.54tft-wifi/1.0.1',
    'Accept-Language': 'zh-CN',
    'X-Language': 'zh-CN',
    'Device-Id': mac,
    'Client-Id': uuid,
    'Content-Type': 'application/json',
  };

  final client = http.Client();
  try {
    final response = await client.post(
      Uri.parse(url),
      headers: headers,
      body: jsonEncode(payload),
    );

    stdout.writeln('=== OTA LIVE REQUEST ===');
    stdout.writeln('URL: $url');
    stdout.writeln('Headers: ${jsonEncode(headers)}');
    stdout.writeln('Payload: ${_prettyJson(jsonEncode(payload))}');
    stdout.writeln('=== OTA LIVE RESPONSE ===');
    stdout.writeln('Status: ${response.statusCode}');
    stdout.writeln('Body: ${_prettyJson(response.body)}');
  } catch (e, st) {
    stderr.writeln('Live OTA request failed: $e');
    stderr.writeln(st);
    exitCode = 1;
  } finally {
    client.close();
  }
}

String? _argValue(List<String> args, String key) {
  final index = args.indexOf(key);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}

String _generateMac(Random random) {
  final values = List<int>.generate(6, (_) => random.nextInt(0x100));
  return values
      .map((value) => value.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(':');
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

String _prettyJson(String value) {
  try {
    final decoded = jsonDecode(value);
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(decoded);
  } catch (_) {
    return value;
  }
}
