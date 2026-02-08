import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/logging/app_logger.dart';
import '../mcp/mcp_server.dart';

class LocalWebHostService {
  LocalWebHostService._();

  static final LocalWebHostService instance = LocalWebHostService._();

  final StreamController<LocalWebHostState> _stateController =
      StreamController<LocalWebHostState>.broadcast();
  final McpServer _mcpServer = McpServer.shared;

  HttpServer? _server;
  LocalWebHostState _state = const LocalWebHostState.stopped();
  int _nextRpcId = 20000;
  static const Duration _mcpTimeout = Duration(seconds: 8);
  String? _indexTemplateCache;
  String? _managerTemplateCache;
  String? _cssCache;
  String? _jsCache;
  String? _managerJsCache;

  Stream<LocalWebHostState> get stateStream => _stateController.stream;
  LocalWebHostState get state => _state;

  Future<LocalWebHostState> start({int preferredPort = 8080}) async {
    if (_server != null && _state.isRunning) {
      return _state;
    }

    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        preferredPort,
        shared: true,
      );
    } on SocketException {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, 0, shared: true);
    } catch (error) {
      final failed = LocalWebHostState.error('Không thể mở web host: $error');
      _setState(failed);
      return failed;
    }

    final ip = await _resolveLocalIpv4();
    final host = ip ?? '127.0.0.1';
    final server = _server;
    if (server == null) {
      final failed = const LocalWebHostState.error(
        'Không thể mở web host (server null).',
      );
      _setState(failed);
      return failed;
    }

    final running = LocalWebHostState.running(ip: host, port: server.port);
    _setState(running);
    AppLogger.event(
      'WebHost',
      'started',
      fields: <String, Object?>{'ip': host, 'port': server.port},
    );
    unawaited(_serve(server));
    return running;
  }

  Future<void> restart({int preferredPort = 8080}) async {
    await stop();
    await start(preferredPort: preferredPort);
  }

  Future<void> stop() async {
    final server = _server;
    _server = null;
    if (server != null) {
      try {
        await server.close(force: true);
      } catch (_) {}
      AppLogger.event('WebHost', 'stopped');
    }
    _setState(const LocalWebHostState.stopped());
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        await _handleRequest(request);
      }
    } catch (error) {
      final failed = LocalWebHostState.error('Web host lỗi: $error');
      _setState(failed);
      AppLogger.event(
        'WebHost',
        'server_error',
        fields: <String, Object?>{'message': error.toString()},
        level: 'E',
      );
    } finally {
      if (identical(_server, server)) {
        _server = null;
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path;
      final method = request.method.toUpperCase();

      if (path == '/' || path.isEmpty) {
        await _writeHtml(request, await _indexHtml());
        return;
      }

      if ((path == '/manager' || path == '/manager/') && method == 'GET') {
        await _writeHtml(request, await _managerHtml());
        return;
      }

      if (path == '/console.css' && method == 'GET') {
        await _writeCss(request, await _consoleCss());
        return;
      }

      if (path == '/console.js' && method == 'GET') {
        await _writeJavaScript(request, await _consoleJs());
        return;
      }

      if (path == '/manager.js' && method == 'GET') {
        await _writeJavaScript(request, await _managerJs());
        return;
      }

      if (path == '/health' && method == 'GET') {
        await _writeJson(request, <String, Object?>{
          'ok': true,
          'timestamp': DateTime.now().toIso8601String(),
        });
        return;
      }

      if (path == '/info' && method == 'GET') {
        await _writeJson(request, <String, Object?>{
          'name': 'voicebot_local_host',
          'url': _state.url,
          'status': _state.isRunning ? 'running' : 'stopped',
          'time': DateTime.now().toIso8601String(),
        });
        return;
      }

      if (path == '/api/documents' && method == 'GET') {
        await _handleListDocuments(request);
        return;
      }

      if (path == '/api/documents/content' && method == 'GET') {
        await _handleGetDocumentContent(request);
        return;
      }

      if (path == '/api/documents/text' && method == 'POST') {
        await _handleUploadText(request);
        return;
      }

      if (path == '/api/documents' && method == 'DELETE') {
        await _handleClearDocuments(request);
        return;
      }

      if (path == '/api/search' && method == 'POST') {
        await _handleSearch(request);
        return;
      }

      await _writeJson(request, <String, Object?>{
        'error': 'Not found',
      }, statusCode: HttpStatus.notFound);
    } catch (error) {
      await _writeJson(request, <String, Object?>{
        'error': error.toString(),
      }, statusCode: HttpStatus.internalServerError);
    }
  }

  Future<void> _handleListDocuments(HttpRequest request) async {
    final result = await _callTool(name: 'self.knowledge.list_documents');
    final payload = _decodeToolPayload(result);
    var documents = _extractRows(payload, key: 'documents');
    final keyword = (request.uri.queryParameters['q'] ?? '').trim();
    final sort = (request.uri.queryParameters['sort'] ?? 'updated_desc').trim();
    if (keyword.isNotEmpty) {
      final folded = keyword.toLowerCase();
      documents = documents.where((item) {
        final name = (item['name'] ?? '').toString().toLowerCase();
        return name.contains(folded);
      }).toList();
    }
    _sortDocuments(documents, sort: sort);
    final count = keyword.isNotEmpty
        ? documents.length
        : _extractCount(payload, fallback: documents.length);
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'count': count,
      'documents': documents,
    });
  }

  Future<void> _handleGetDocumentContent(HttpRequest request) async {
    final name = (request.uri.queryParameters['name'] ?? '').trim();
    if (name.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu tên tài liệu.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }
    final result = await _callTool(
      name: 'self.knowledge.get_document',
      arguments: <String, dynamic>{'name': name},
    );
    final payload = _decodeToolPayload(result);
    if (payload is! Map) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Không đọc được nội dung tài liệu.',
      }, statusCode: HttpStatus.notFound);
      return;
    }
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'document': Map<String, Object?>.from(payload),
    });
  }

  Future<void> _handleUploadText(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final name = (body['name'] as String? ?? '').trim();
    final text = (body['text'] as String? ?? '').trim();
    if (name.isEmpty || text.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu name hoặc text.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }
    final validation = LocalKnowledgeBase.validateKdocContent(text);
    if (!validation.isValid) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Nội dung không đúng chuẩn KDOC v1.',
        'errors': validation.errors,
        'format': 'KDOC:v1',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final upload = await _callTool(
      name: 'self.knowledge.upload_text',
      arguments: <String, dynamic>{'name': name, 'text': text},
    );
    final uploadPayload = _decodeToolPayload(upload);
    final listResult = await _callTool(name: 'self.knowledge.list_documents');
    final listPayload = _decodeToolPayload(listResult);
    final documents = _extractRows(listPayload, key: 'documents');
    final count = _extractCount(listPayload, fallback: documents.length);
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'upload': uploadPayload,
      'count': count,
      'documents': documents,
    });
  }

  Future<void> _handleClearDocuments(HttpRequest request) async {
    final clear = await _callTool(name: 'self.knowledge.clear');
    final clearPayload = _decodeToolPayload(clear);
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'result': clearPayload,
      'count': 0,
      'documents': const <Map<String, Object?>>[],
    });
  }

  Future<void> _handleSearch(HttpRequest request) async {
    final body = await _readJsonBody(request);
    final query = (body['query'] as String? ?? '').trim();
    final topK = (body['top_k'] as num?)?.toInt() ?? 5;
    if (query.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu query.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }
    final result = await _callTool(
      name: 'self.knowledge.search',
      arguments: <String, dynamic>{'query': query, 'top_k': topK.clamp(1, 10)},
    );
    final payload = _decodeToolPayload(result);
    final rows = _extractRows(payload, key: 'results');
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'query': query,
      'results': rows,
    });
  }

  Future<Map<String, dynamic>> _readJsonBody(HttpRequest request) async {
    final body = await utf8.decoder.bind(request).join();
    if (body.trim().isEmpty) {
      return <String, dynamic>{};
    }
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    return <String, dynamic>{};
  }

  Future<Map<String, dynamic>> _callTool({
    required String name,
    Map<String, dynamic> arguments = const <String, dynamic>{},
  }) async {
    final requestId = _nextRpcId++;
    final requestPayload = <String, dynamic>{
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'tools/call',
      'params': <String, dynamic>{'name': name, 'arguments': arguments},
    };
    AppLogger.event(
      'WebHost',
      'mcp_call',
      fields: <String, Object?>{'id': requestId, 'name': name},
      level: 'D',
    );
    final response = await _mcpServer
        .handleMessage(requestPayload)
        .timeout(_mcpTimeout);

    if (response == null) {
      throw Exception('MCP không phản hồi.');
    }

    final error = response['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.isNotEmpty) {
        throw Exception(message);
      }
      throw Exception('MCP trả lỗi không xác định.');
    }

    final result = response['result'];
    if (result is Map<String, dynamic>) {
      return result;
    }
    if (result is Map) {
      AppLogger.event(
        'WebHost',
        'mcp_ok',
        fields: <String, Object?>{'id': requestId, 'name': name},
        level: 'D',
      );
      return Map<String, dynamic>.from(result);
    }
    throw Exception('MCP trả kết quả không hợp lệ.');
  }

  Object? _decodeToolPayload(Map<String, dynamic> result) {
    final content = result['content'];
    if (content is! List || content.isEmpty) {
      return null;
    }
    for (final item in content) {
      if (item is! Map) {
        continue;
      }
      final text = item['text'];
      if (text is! String) {
        continue;
      }
      final trimmed = text.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return jsonDecode(trimmed);
        } catch (_) {
          return trimmed;
        }
      }
      return trimmed;
    }
    return null;
  }

  List<Map<String, dynamic>> _extractRows(
    Object? payload, {
    required String key,
  }) {
    if (payload is! Map) {
      return <Map<String, dynamic>>[];
    }
    final items = payload[key];
    if (items is! List) {
      return <Map<String, dynamic>>[];
    }
    return items
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  int _extractCount(Object? payload, {required int fallback}) {
    if (payload is! Map) {
      return fallback;
    }
    final value = payload['count'];
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  void _sortDocuments(List<Map<String, dynamic>> rows, {required String sort}) {
    switch (sort) {
      case 'name_asc':
        rows.sort(
          (a, b) => (a['name'] ?? '').toString().compareTo(
            (b['name'] ?? '').toString(),
          ),
        );
        return;
      case 'name_desc':
        rows.sort(
          (a, b) => (b['name'] ?? '').toString().compareTo(
            (a['name'] ?? '').toString(),
          ),
        );
        return;
      case 'updated_asc':
        rows.sort(
          (a, b) => (a['updated_at'] ?? '').toString().compareTo(
            (b['updated_at'] ?? '').toString(),
          ),
        );
        return;
      case 'updated_desc':
      default:
        rows.sort(
          (a, b) => (b['updated_at'] ?? '').toString().compareTo(
            (a['updated_at'] ?? '').toString(),
          ),
        );
    }
  }

  Future<void> _writeHtml(HttpRequest request, String html) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.html
      ..write(html);
    await request.response.close();
  }

  Future<void> _writeCss(HttpRequest request, String css) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, 'text/css; charset=utf-8')
      ..write(css);
    await request.response.close();
  }

  Future<void> _writeJavaScript(HttpRequest request, String script) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(
        HttpHeaders.contentTypeHeader,
        'application/javascript; charset=utf-8',
      )
      ..write(script);
    await request.response.close();
  }

  Future<void> _writeJson(
    HttpRequest request,
    Map<String, Object?> data, {
    int statusCode = HttpStatus.ok,
  }) async {
    request.response
      ..statusCode = statusCode
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(data));
    await request.response.close();
  }

  Future<String> _indexHtml() async {
    final template = await _loadAsset(
      'assets/web_host/index.html',
      cached: _indexTemplateCache,
      assign: (value) => _indexTemplateCache = value,
    );
    final url = _state.url ?? 'unknown';
    return template.replaceAll('{{WEB_HOST_URL}}', url);
  }

  Future<String> _consoleCss() async {
    return _loadAsset(
      'assets/web_host/console.css',
      cached: _cssCache,
      assign: (value) => _cssCache = value,
    );
  }

  Future<String> _managerHtml() async {
    final template = await _loadAsset(
      'assets/web_host/manager.html',
      cached: _managerTemplateCache,
      assign: (value) => _managerTemplateCache = value,
    );
    final url = _state.url ?? 'unknown';
    return template.replaceAll('{{WEB_HOST_URL}}', url);
  }

  Future<String> _consoleJs() async {
    return _loadAsset(
      'assets/web_host/console.js',
      cached: _jsCache,
      assign: (value) => _jsCache = value,
    );
  }

  Future<String> _managerJs() async {
    return _loadAsset(
      'assets/web_host/manager.js',
      cached: _managerJsCache,
      assign: (value) => _managerJsCache = value,
    );
  }

  Future<String> _loadAsset(
    String assetPath, {
    required String? cached,
    required void Function(String) assign,
  }) async {
    if (cached != null) {
      return cached;
    }
    final content = await rootBundle.loadString(assetPath);
    assign(content);
    return content;
  }

  Future<String?> _resolveLocalIpv4() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback && !address.address.startsWith('169.254.')) {
            return address.address;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  void _setState(LocalWebHostState next) {
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}

class LocalWebHostState {
  const LocalWebHostState._({
    required this.isRunning,
    this.ip,
    this.port,
    this.message,
  });

  const LocalWebHostState.stopped()
    : this._(isRunning: false, message: 'Web host đang dừng');

  const LocalWebHostState.running({required String ip, required int port})
    : this._(
        isRunning: true,
        ip: ip,
        port: port,
        message: 'Web host đang chạy',
      );

  const LocalWebHostState.error(String message)
    : this._(isRunning: false, message: message);

  final bool isRunning;
  final String? ip;
  final int? port;
  final String? message;

  String? get url {
    if (!isRunning || ip == null || port == null) {
      return null;
    }
    return 'http://$ip:$port';
  }
}
