import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:mime/mime.dart' as mime;
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../../core/logging/app_logger.dart';
import '../mcp/mcp_server.dart';
import 'document_image_store.dart';

class LocalWebHostService {
  LocalWebHostService._();

  static final LocalWebHostService instance = LocalWebHostService._();

  final StreamController<LocalWebHostState> _stateController =
      StreamController<LocalWebHostState>.broadcast();
  final McpServer _mcpServer = McpServer.shared;

  HttpServer? _server;
  LocalWebHostState _state = const LocalWebHostState.stopped();
  int _nextRpcId = 20000;
  int _nextHttpRequestId = 1;
  static const Duration _mcpTimeout = Duration(seconds: 8);
  String? _indexTemplateCache;
  String? _managerTemplateCache;
  String? _cssCache;
  String? _jsCache;
  String? _managerJsCache;
  Future<DocumentImageStore>? _imageStoreFuture;

  static const Set<String> _allowedImageMimeTypes = <String>{
    'image/jpeg',
    'image/png',
    'image/webp',
  };

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

      if (path == '/api/documents/image' && method == 'POST') {
        await _handleUploadImage(request);
        return;
      }

      if (path == '/api/documents/images' && method == 'GET') {
        await _handleListDocumentImages(request);
        return;
      }

      if (path == '/api/documents/image/content' && method == 'GET') {
        await _handleGetDocumentImageContent(request);
        return;
      }

      if (path == '/api/documents/image' && method == 'DELETE') {
        await _handleDeleteDocumentImage(request);
        return;
      }

      if (path == '/api/documents' && method == 'DELETE') {
        final name = (request.uri.queryParameters['name'] ?? '').trim();
        if (name.isNotEmpty) {
          await _handleDeleteDocument(request);
        } else {
          await _handleClearDocuments(request);
        }
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
    final oldName = (body['old_name'] as String? ?? '').trim();
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
    if (oldName.isNotEmpty && oldName != name) {
      final imageStore = await _getImageStore();
      final moved = await imageStore.migrateDocumentName(
        oldName: oldName,
        newName: name,
      );
      AppLogger.event(
        'WebHost',
        'image_doc_rename',
        fields: <String, Object?>{
          'from': oldName,
          'to': name,
          'moved_images': moved,
        },
      );
    }
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
    final imageStore = await _getImageStore();
    final removedImages = await imageStore.clearAll();
    AppLogger.event(
      'WebHost',
      'image_clear_all',
      fields: <String, Object?>{'removed_images': removedImages},
    );
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'result': clearPayload,
      'removed_images': removedImages,
      'count': 0,
      'documents': const <Map<String, Object?>>[],
    });
  }

  Future<void> _handleDeleteDocument(HttpRequest request) async {
    final name = (request.uri.queryParameters['name'] ?? '').trim();
    if (name.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu tên tài liệu.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }
    final result = await _callTool(
      name: 'self.knowledge.delete_document',
      arguments: <String, dynamic>{'name': name},
    );
    final payload = _decodeToolPayload(result);
    if (payload is! Map) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Không thể xóa tài liệu.',
      }, statusCode: HttpStatus.internalServerError);
      return;
    }

    final deleted = payload['deleted'] == true;
    final imageStore = await _getImageStore();
    final removedImages = await imageStore.clearDocument(name);
    if (!deleted && removedImages == 0) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Tài liệu không tồn tại.',
      }, statusCode: HttpStatus.notFound);
      return;
    }
    AppLogger.event(
      'WebHost',
      'document_delete',
      fields: <String, Object?>{
        'name': name,
        'deleted': deleted,
        'removed_images': removedImages,
      },
    );
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'deleted': deleted,
      'result': payload,
      'removed_images': removedImages,
    });
  }

  Future<void> _handleUploadImage(HttpRequest request) async {
    final requestId = _nextHttpRequestId++;
    try {
      final contentType = request.headers.contentType;
      final mimeTypeHeader = contentType?.mimeType.toLowerCase() ?? '';
      final isJsonBody = mimeTypeHeader == 'application/json';
      if (isJsonBody) {
        final upload = await _readImageUploadJsonRequest(request);
        final normalizedMimeType =
            _normalizeImageMimeType(upload.mimeType, fileName: upload.fileName);
        if (!_allowedImageMimeTypes.contains(normalizedMimeType)) {
          await _writeJson(request, <String, Object?>{
            'ok': false,
            'error': 'Định dạng ảnh không hỗ trợ. Chỉ chấp nhận JPEG/PNG/WEBP.',
          }, statusCode: HttpStatus.badRequest);
          return;
        }
        if (upload.bytes.length > AppConfig.webHostImageUploadMaxBytes) {
          final maxMb = AppConfig.webHostImageUploadMaxMb;
          await _writeJson(request, <String, Object?>{
            'ok': false,
            'error': 'Ảnh vượt quá giới hạn ${maxMb}MB.',
          }, statusCode: HttpStatus.badRequest);
          return;
        }

        final imageStore = await _getImageStore();
        final created = await imageStore.saveImage(
          docName: upload.docName,
          fileName: upload.fileName,
          mimeType: normalizedMimeType,
          bytes: upload.bytes,
          caption: upload.caption,
        );
        final imageId = (created['id'] ?? '').toString();
        final image = <String, Object?>{
          ...created,
          'url':
              '/api/documents/image/content?id=${Uri.encodeQueryComponent(imageId)}',
        };
        AppLogger.event(
          'WebHost',
          'image_upload',
          fields: <String, Object?>{
            'request_id': requestId,
            'doc': upload.docName,
            'image_id': imageId,
            'mime': normalizedMimeType,
            'bytes': upload.bytes.length,
          },
        );
        await _writeJson(request, <String, Object?>{
          'ok': true,
          'image': image,
        });
        return;
      }

      final upload = await _readImageUploadMultipartRequest(request);
      final normalizedMimeType =
          _normalizeImageMimeType(upload.mimeType, fileName: upload.fileName);
      if (!_allowedImageMimeTypes.contains(normalizedMimeType)) {
        await _safeDeleteFile(upload.file);
        await _writeJson(request, <String, Object?>{
          'ok': false,
          'error': 'Định dạng ảnh không hỗ trợ. Chỉ chấp nhận JPEG/PNG/WEBP.',
        }, statusCode: HttpStatus.badRequest);
        return;
      }

      final imageStore = await _getImageStore();
      final created = await imageStore.saveImageFile(
        docName: upload.docName,
        fileName: upload.fileName,
        mimeType: normalizedMimeType,
        sourceFile: upload.file,
        bytes: upload.bytes,
        caption: upload.caption,
      );
      final imageId = (created['id'] ?? '').toString();
      final image = <String, Object?>{
        ...created,
        'url': '/api/documents/image/content?id=${Uri.encodeQueryComponent(imageId)}',
      };
      AppLogger.event(
        'WebHost',
        'image_upload',
        fields: <String, Object?>{
          'request_id': requestId,
          'doc': upload.docName,
          'image_id': imageId,
          'mime': normalizedMimeType,
          'bytes': upload.bytes,
        },
      );
      await _writeJson(request, <String, Object?>{
        'ok': true,
        'image': image,
      });
    } catch (error) {
      AppLogger.event(
        'WebHost',
        'image_upload_error',
        fields: <String, Object?>{
          'request_id': requestId,
          'error': error.toString(),
        },
        level: 'E',
      );
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': error.toString(),
      }, statusCode: HttpStatus.badRequest);
    }
  }

  Future<_ImageUploadRequest> _readImageUploadJsonRequest(
    HttpRequest request,
  ) async {
    final body = await _readJsonBody(request);
    final docName = (body['name'] as String? ?? '').trim();
    if (docName.isEmpty) {
      throw Exception('Thiếu trường name (tên tài liệu).');
    }
    final fileNameRaw = (body['file_name'] as String? ?? 'image').trim();
    final fileName = fileNameRaw.isEmpty ? 'image' : fileNameRaw;
    final mimeType = (body['mime_type'] as String? ?? '').trim().toLowerCase();
    final dataBase64 = ((body['data_base64'] ?? body['data']) as String? ?? '')
        .trim();
    if (dataBase64.isEmpty) {
      throw Exception('Thiếu dữ liệu ảnh base64.');
    }
    late List<int> decoded;
    try {
      decoded = base64Decode(dataBase64);
    } on FormatException {
      throw Exception('Dữ liệu ảnh base64 không hợp lệ.');
    }
    if (decoded.isEmpty) {
      throw Exception('Dữ liệu ảnh rỗng.');
    }
    final normalizedMimeType =
        mimeType.isEmpty ? _guessMimeTypeFromFileName(fileName) : mimeType;
    final caption = (body['caption'] as String?)?.trim();
    return _ImageUploadRequest(
      docName: docName,
      fileName: fileName,
      mimeType: normalizedMimeType,
      bytes: Uint8List.fromList(decoded),
      caption: caption?.isEmpty ?? true ? null : caption,
    );
  }

  Future<_ImageUploadFileRequest> _readImageUploadMultipartRequest(
    HttpRequest request,
  ) async {
    final contentType = request.headers.contentType;
    final isMultipart =
        contentType != null &&
        contentType.primaryType.toLowerCase() == 'multipart' &&
        contentType.subType.toLowerCase() == 'form-data';
    if (!isMultipart) {
      throw Exception('Content-Type phải là multipart/form-data.');
    }
    final boundary =
        (contentType.parameters['boundary'] ?? '').trim().replaceAll('"', '');
    if (boundary.isEmpty) {
      throw Exception('Thiếu boundary trong multipart/form-data.');
    }

    String docName = '';
    String? caption;
    String? fileName;
    String fileMimeType = '';
    File? tempFile;
    int totalBytes = 0;
    try {
      final transformer = mime.MimeMultipartTransformer(boundary);
      await for (final part in transformer.bind(request)) {
        final headers = part.headers;
        final contentDisposition = headers['content-disposition'] ?? '';
        final fieldName =
            _extractDispositionValue(contentDisposition, 'name')?.trim();
        final partFileName = _extractDispositionValue(
          contentDisposition,
          'filename',
        );

        if (partFileName != null && partFileName.trim().isNotEmpty) {
          if (tempFile != null) {
            await part.drain();
            throw Exception('Chỉ hỗ trợ 1 file ảnh mỗi lần upload.');
          }
          fileName = partFileName.trim();
          fileMimeType =
              (headers['content-type'] ?? '').split(';').first.trim();
          tempFile = await _createTempUploadFile();
          final sink = tempFile.openWrite();
          try {
            await for (final chunk in part) {
              totalBytes += chunk.length.toInt();
              if (totalBytes > AppConfig.webHostImageUploadMaxBytes) {
                throw Exception(
                  'Ảnh vượt quá giới hạn ${AppConfig.webHostImageUploadMaxMb}MB.',
                );
              }
              sink.add(chunk);
            }
          } finally {
            await sink.close();
          }
          continue;
        }

        final value = await utf8.decoder.bind(part).join();
        if (fieldName == 'name') {
          docName = value.trim();
        } else if (fieldName == 'caption') {
          caption = value.trim();
        }
      }
    } catch (error) {
      if (tempFile != null) {
        await _safeDeleteFile(tempFile);
      }
      rethrow;
    }

    if (docName.trim().isEmpty) {
      if (tempFile != null) {
        await _safeDeleteFile(tempFile);
      }
      throw Exception('Thiếu trường name (tên tài liệu).');
    }
    if (tempFile == null || totalBytes == 0) {
      if (tempFile != null) {
        await _safeDeleteFile(tempFile);
      }
      throw Exception('Không nhận được file ảnh upload.');
    }

    final normalizedFileName =
        (fileName ?? 'image').trim().isEmpty ? 'image' : fileName!.trim();
    final normalizedMimeType =
        fileMimeType.trim().isEmpty
            ? _guessMimeTypeFromFileName(normalizedFileName)
            : fileMimeType.trim().toLowerCase();
    final normalizedCaption =
        (caption?.trim().isEmpty ?? true) ? null : caption!.trim();
    return _ImageUploadFileRequest(
      docName: docName.trim(),
      fileName: normalizedFileName,
      mimeType: normalizedMimeType,
      file: tempFile,
      bytes: totalBytes,
      caption: normalizedCaption,
    );
  }

  Future<void> _handleListDocumentImages(HttpRequest request) async {
    final requestId = _nextHttpRequestId++;
    final name = (request.uri.queryParameters['name'] ?? '').trim();
    if (name.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu tên tài liệu.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }
    final imageStore = await _getImageStore();
    final images = await imageStore.listImagesByDocument(name);
    final enriched = images.map((item) {
      final id = (item['id'] ?? '').toString();
      return <String, Object?>{
        ...item,
        'url': '/api/documents/image/content?id=${Uri.encodeQueryComponent(id)}',
      };
    }).toList(growable: false);

    AppLogger.event(
      'WebHost',
      'image_list',
      fields: <String, Object?>{
        'request_id': requestId,
        'doc': name,
        'count': enriched.length,
      },
    );
    await _writeJson(request, <String, Object?>{
      'ok': true,
      'doc_name': name,
      'count': enriched.length,
      'images': enriched,
    });
  }

  Future<void> _handleGetDocumentImageContent(HttpRequest request) async {
    final imageId = (request.uri.queryParameters['id'] ?? '').trim();
    if (imageId.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu id ảnh.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }

    final imageStore = await _getImageStore();
    final content = await imageStore.readImageBinary(imageId);
    if (content == null) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Không tìm thấy ảnh.',
      }, statusCode: HttpStatus.notFound);
      return;
    }
    await _writeBinary(
      request,
      bytes: content.bytes,
      mimeType: content.mimeType,
      fileName: content.fileName,
    );
  }

  Future<void> _handleDeleteDocumentImage(HttpRequest request) async {
    final requestId = _nextHttpRequestId++;
    final imageId = (request.uri.queryParameters['id'] ?? '').trim();
    if (imageId.isEmpty) {
      await _writeJson(request, <String, Object?>{
        'ok': false,
        'error': 'Thiếu id ảnh.',
      }, statusCode: HttpStatus.badRequest);
      return;
    }
    final imageStore = await _getImageStore();
    final removed = await imageStore.deleteImage(imageId);
    AppLogger.event(
      'WebHost',
      'image_delete',
      fields: <String, Object?>{
        'request_id': requestId,
        'image_id': imageId,
        'removed': removed,
      },
      level: removed ? 'I' : 'W',
    );
    await _writeJson(request, <String, Object?>{
      'ok': removed,
      'removed': removed,
      if (!removed) 'error': 'Không tìm thấy ảnh để xóa.',
    }, statusCode: removed ? HttpStatus.ok : HttpStatus.notFound);
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


  String _guessMimeTypeFromFileName(String fileName) {
    final lowered = fileName.toLowerCase();
    if (lowered.endsWith('.jpg') || lowered.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lowered.endsWith('.png')) {
      return 'image/png';
    }
    if (lowered.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'application/octet-stream';
  }

  String _normalizeImageMimeType(
    String raw, {
    String? fileName,
  }) {
    var lowered = raw.trim().toLowerCase();
    if (lowered.isEmpty && fileName != null && fileName.trim().isNotEmpty) {
      lowered = _guessMimeTypeFromFileName(fileName);
    }
    if (lowered == 'image/jpg' || lowered == 'image/pjpeg') {
      return 'image/jpeg';
    }
    return lowered;
  }

  String? _extractDispositionValue(String header, String key) {
    final quoted = RegExp('$key="([^"]*)"').firstMatch(header);
    if (quoted != null) {
      return quoted.group(1);
    }
    final plain = RegExp('$key=([^;\\s]+)').firstMatch(header);
    return plain?.group(1);
  }

  Future<File> _createTempUploadFile() async {
    final tempDir = await getTemporaryDirectory();
    final name =
        'voicebot_upload_${DateTime.now().microsecondsSinceEpoch}_$_nextHttpRequestId.tmp';
    return File('${tempDir.path}${Platform.pathSeparator}$name');
  }

  Future<void> _safeDeleteFile(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
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

  Future<void> _writeBinary(
    HttpRequest request, {
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.set(HttpHeaders.contentTypeHeader, mimeType)
      ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
      ..headers.set(
        'content-disposition',
        'inline; filename="${Uri.encodeComponent(fileName)}"',
      )
      ..add(bytes);
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
    return template
        .replaceAll('{{WEB_HOST_URL}}', url)
        .replaceAll(
          '{{MAX_IMAGE_UPLOAD_MB}}',
          AppConfig.webHostImageUploadMaxMb.toString(),
        );
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

  Future<DocumentImageStore> _getImageStore() {
    _imageStoreFuture ??= _createImageStore();
    return _imageStoreFuture!;
  }

  Future<DocumentImageStore> _createImageStore() async {
    final baseDir = await getApplicationDocumentsDirectory();
    final root = Directory(
      '${baseDir.path}${Platform.pathSeparator}voicebot${Platform.pathSeparator}web_host_images',
    );
    final store = DocumentImageStore(
      rootDirectory: root,
      maxFileBytes: AppConfig.webHostImageUploadMaxBytes,
    );
    await store.initialize();
    return store;
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

class _ImageUploadRequest {
  const _ImageUploadRequest({
    required this.docName,
    required this.fileName,
    required this.mimeType,
    required this.bytes,
    this.caption,
  });

  final String docName;
  final String fileName;
  final String mimeType;
  final Uint8List bytes;
  final String? caption;
}

class _ImageUploadFileRequest {
  const _ImageUploadFileRequest({
    required this.docName,
    required this.fileName,
    required this.mimeType,
    required this.file,
    required this.bytes,
    this.caption,
  });

  final String docName;
  final String fileName;
  final String mimeType;
  final File file;
  final int bytes;
  final String? caption;
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
