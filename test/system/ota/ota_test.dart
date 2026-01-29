import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:voicebot/core/system/ota/model/device_info.dart' as device_info;
import 'package:voicebot/system/ota/ota.dart' as system_ota;

class _CapturedRequest {
  _CapturedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.bodyBytes,
  });

  final String method;
  final Uri url;
  final Map<String, String> headers;
  final List<int> bodyBytes;

  String get bodyText => utf8.decode(bodyBytes);
}

class _FakeHttpOverrides extends HttpOverrides {
  _FakeHttpOverrides(this._client);

  final HttpClient _client;

  @override
  HttpClient createHttpClient(SecurityContext? context) => _client;
}

class _FakeHttpClient extends Fake implements HttpClient {
  _FakeHttpClient(this._handler, this._onRequest);

  final Future<_FakeHttpClientResponse> Function(
    String method,
    Uri url,
    Map<String, String> headers,
    List<int> bodyBytes,
  )
  _handler;
  final void Function(_CapturedRequest request) _onRequest;
  Duration? _connectionTimeout;
  Duration _idleTimeout = const Duration(seconds: 0);

  @override
  Duration? get connectionTimeout => _connectionTimeout;

  @override
  set connectionTimeout(Duration? value) {
    _connectionTimeout = value;
  }

  @override
  Duration get idleTimeout => _idleTimeout;

  @override
  set idleTimeout(Duration value) {
    _idleTimeout = value;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _FakeHttpClientRequest(method, url, _handler, _onRequest);
  }
}

class _FakeHttpClientRequest extends Fake implements HttpClientRequest {
  _FakeHttpClientRequest(this.method, this.uri, this._handler, this._onRequest);

  @override
  final String method;
  @override
  final Uri uri;
  final _FakeHttpHeaders _headers = _FakeHttpHeaders();
  final List<int> _bodyBytes = <int>[];
  final Future<_FakeHttpClientResponse> Function(
    String method,
    Uri url,
    Map<String, String> headers,
    List<int> bodyBytes,
  )
  _handler;
  final void Function(_CapturedRequest request) _onRequest;

  @override
  HttpHeaders get headers => _headers;

  @override
  int contentLength = -1;

  @override
  bool followRedirects = true;

  @override
  int maxRedirects = 5;

  @override
  bool persistentConnection = true;

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final captured = _CapturedRequest(
      method: method,
      url: uri,
      headers: _headers.toSingleValueMap(),
      bodyBytes: _bodyBytes,
    );
    _onRequest(captured);
    return _handler(method, uri, _headers.toSingleValueMap(), _bodyBytes);
  }
}

class _FakeHttpHeaders extends Fake implements HttpHeaders {
  final Map<String, List<String>> _values = <String, List<String>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = <String>[value.toString()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _values.putIfAbsent(name, () => <String>[]).add(value.toString());
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _values.forEach(action);
  }

  Map<String, String> toSingleValueMap() {
    return _values.map((key, value) => MapEntry(key, value.join(',')));
  }
}

class _FakeHttpClientResponse extends Fake implements HttpClientResponse {
  _FakeHttpClientResponse(this.statusCode, String body)
    : _body = utf8.encode(body);

  final List<int> _body;

  @override
  final int statusCode;

  @override
  int get contentLength => _body.length;

  @override
  HttpHeaders get headers => _FakeHttpHeaders();

  @override
  String get reasonPhrase => '';

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => const <RedirectInfo>[];

  @override
  bool get persistentConnection => true;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const storageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );
  final Map<String, String> storage = <String, String>{};

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(storageChannel, (call) async {
      final args =
          (call.arguments as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return key == null ? null : storage[key];
        case 'write':
          if (key != null) {
            storage[key] = args['value'] as String? ?? '';
          }
          return null;
        case 'delete':
          if (key != null) {
            storage.remove(key);
          }
          return null;
        case 'deleteAll':
          storage.clear();
          return null;
        case 'readAll':
          return storage;
        default:
          return null;
      }
    });
  });

  setUp(() {
    storage.clear();
  });

  group('OTA checkVersion', () {
    test('Given short URL, When checkVersion, Then returns false', () async {
      final ota = system_ota.Ota(device_info.DummyDataGenerator.generate());
      final result = await ota.checkVersion('short');
      expect(result, isFalse);
    });

    test(
      'Given valid response, When checkVersion, Then sends POST and parses OTA result',
      () async {
        _CapturedRequest? captured;
        final responseJson = _validOtaResponseJson();
        final fakeClient = _FakeHttpClient((
          method,
          url,
          headers,
          bodyBytes,
        ) async {
          return _FakeHttpClientResponse(200, responseJson);
        }, (request) => captured = request);
        final overrides = _FakeHttpOverrides(fakeClient);

        storage['ota_device_mac'] = 'AA:BB:CC:DD:EE:FF';
        storage['ota_device_uuid'] = 'device-uuid-123';

        system_ota.Ota? ota;
        final result = await HttpOverrides.runZoned(() async {
          ota = system_ota.Ota(device_info.DummyDataGenerator.generate());
          return ota!.checkVersion('https://example.com/ota');
        }, createHttpClient: overrides.createHttpClient);

        expect(result, isTrue);
        expect(ota, isNotNull);
        expect(ota!.otaResult, isNotNull);
        expect(ota!.otaResult?.firmware?.version, equals('1.0.2'));
        expect(captured, isNotNull);
        expect(captured!.method, equals('POST'));
        expect(captured!.headers['Device-Id'], equals('AA:BB:CC:DD:EE:FF'));
        expect(captured!.headers['Client-Id'], equals('device-uuid-123'));
        expect(captured!.headers['Content-Type'], equals('application/json'));

        // Print payload/response JSON + activation code for visibility during test runs.
        // ignore: avoid_print
        print('=== TEST OTA REQUEST JSON ===\n${captured!.bodyText}');
        // ignore: avoid_print
        print('=== TEST OTA RESPONSE JSON ===\n$responseJson');
        final responseMap = jsonDecode(responseJson) as Map<String, dynamic>;
        final activation = responseMap['activation'] as Map<String, dynamic>?;
        final activationCode = activation?['code'] as String?;
        // ignore: avoid_print
        print('=== TEST OTA ACTIVATION CODE ===\n${activationCode ?? '-'}');

        final payload = jsonDecode(captured!.bodyText) as Map<String, dynamic>;
        expect(payload['application'], isA<Map<String, dynamic>>());
        expect(payload['mac_address'], equals('AA:BB:CC:DD:EE:FF'));
        expect(payload['uuid'], equals('device-uuid-123'));
      },
    );

    test(
      'Given non-2xx response, When checkVersion, Then returns false',
      () async {
        final fakeClient = _FakeHttpClient((
          method,
          url,
          headers,
          bodyBytes,
        ) async {
          return _FakeHttpClientResponse(500, 'error');
        }, (_) {});
        final overrides = _FakeHttpOverrides(fakeClient);

        final ota = system_ota.Ota(device_info.DummyDataGenerator.generate());
        final result = await HttpOverrides.runZoned(
          () => ota.checkVersion('https://example.com/ota'),
          createHttpClient: overrides.createHttpClient,
        );

        expect(result, isFalse);
        expect(ota.otaResult, isNull);
      },
    );

    test('Given empty body, When checkVersion, Then returns false', () async {
      final fakeClient = _FakeHttpClient((
        method,
        url,
        headers,
        bodyBytes,
      ) async {
        return _FakeHttpClientResponse(200, '');
      }, (_) {});
      final overrides = _FakeHttpOverrides(fakeClient);

      final ota = system_ota.Ota(device_info.DummyDataGenerator.generate());
      final result = await HttpOverrides.runZoned(
        () => ota.checkVersion('https://example.com/ota'),
        createHttpClient: overrides.createHttpClient,
      );

      expect(result, isFalse);
      expect(ota.otaResult, isNull);
    });

    test(
      'Given invalid JSON body, When checkVersion, Then returns false',
      () async {
        final fakeClient = _FakeHttpClient((
          method,
          url,
          headers,
          bodyBytes,
        ) async {
          return _FakeHttpClientResponse(200, 'not-json');
        }, (_) {});
        final overrides = _FakeHttpOverrides(fakeClient);

        final ota = system_ota.Ota(device_info.DummyDataGenerator.generate());
        final result = await HttpOverrides.runZoned(
          () => ota.checkVersion('https://example.com/ota'),
          createHttpClient: overrides.createHttpClient,
        );

        expect(result, isFalse);
        expect(ota.otaResult, isNull);
      },
    );
  });
}

String _validOtaResponseJson() {
  final body = <String, dynamic>{
    'mqtt': <String, dynamic>{
      'endpoint': 'ssl://mqtt.example.com',
      'client_id': 'client-123',
      'username': 'user',
      'password': 'pass',
      'publish_topic': 'pub/topic',
      'subscribe_topic': 'sub/topic',
    },
    'activation': <String, dynamic>{'code': 'ABC123', 'message': 'OK'},
    'server_time': <String, dynamic>{
      'timestamp': 1700000000,
      'timezone': 'UTC',
      'timezone_offset': 0,
    },
    'firmware': <String, dynamic>{
      'version': '1.0.2',
      'url': 'https://example.com/fw.bin',
    },
  };
  return jsonEncode(body);
}
