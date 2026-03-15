import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config/app_config.dart';
import '../web_host/document_image_store.dart';

enum McpCallerType { remote, internal, user }

extension on McpCallerType {
  bool get canAccessUserOnly => this != McpCallerType.remote;
}

class McpServer {
  static final McpServer shared = McpServer();

  McpServer({
    McpDeviceController? controller,
    LocalKnowledgeBase? knowledgeBase,
    Future<DocumentImageStore> Function()? imageStoreLoader,
  }) : _controller = controller ?? FlutterMcpDeviceController(),
       _knowledgeBase = knowledgeBase ?? LocalKnowledgeBase(),
       _imageStoreLoader = imageStoreLoader {
    _registerTools();
  }

  final McpDeviceController _controller;
  final LocalKnowledgeBase _knowledgeBase;
  final List<McpTool> _tools = <McpTool>[];
  final Future<DocumentImageStore> Function()? _imageStoreLoader;
  Future<DocumentImageStore>? _imageStoreFuture;
  List<McpTool> get tools => List<McpTool>.unmodifiable(_tools);

  Future<Map<String, dynamic>?> handleMessage(
    Map<String, dynamic> payload, {
    McpCallerType caller = McpCallerType.remote,
  }) async {
    final jsonrpc = payload['jsonrpc'];
    if (jsonrpc != '2.0') {
      return _replyError(
        null,
        -32600,
        'Invalid Request: jsonrpc must be "2.0".',
      );
    }
    final method = payload['method'];
    if (method is! String) {
      return _replyError(
        null,
        -32600,
        'Invalid Request: method must be a string.',
      );
    }
    if (method.startsWith('notifications')) {
      return null;
    }
    final id = payload['id'];
    final requestId = _normalizeRequestId(id);
    if (id == null) {
      return _replyError(null, -32600, 'Invalid Request: missing id.');
    }
    if (requestId == null) {
      return _replyError(
        null,
        -32600,
        'Invalid Request: id must be a string or number.',
      );
    }

    final params = _asStringKeyedMap(payload['params']);
    if (payload['params'] != null && params == null) {
      return _replyError(
        requestId,
        -32602,
        'Invalid params for method: $method',
      );
    }

    switch (method) {
      case 'initialize':
        return _replyResult(requestId, <String, dynamic>{
          'protocolVersion': '2024-11-05',
          'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
          'serverInfo': <String, dynamic>{
            'name': 'voicebot_flutter',
            'version': '1.0.0',
          },
        });
      case 'tools/list':
        if (params != null &&
            params['cursor'] != null &&
            params['cursor'] is! String) {
          return _replyError(
            requestId,
            -32602,
            'Invalid params: cursor must be a string.',
          );
        }
        if (params != null &&
            params['withUserTools'] != null &&
            params['withUserTools'] is! bool) {
          return _replyError(
            requestId,
            -32602,
            'Invalid params: withUserTools must be a boolean.',
          );
        }
        final cursor = params?['cursor'] as String? ?? '';
        final withUserTools =
            caller.canAccessUserOnly &&
            (params?['withUserTools'] as bool? ?? false);
        return _replyResult(
          requestId,
          _buildToolsList(cursor: cursor, withUserTools: withUserTools),
        );
      case 'tools/call':
        if (params == null) {
          return _replyError(requestId, -32602, 'Missing params');
        }
        final name = params['name'];
        if (name is! String) {
          return _replyError(requestId, -32602, 'Missing name');
        }
        final arguments = _asStringKeyedMap(params['arguments']);
        if (params['arguments'] != null && arguments == null) {
          return _replyError(requestId, -32602, 'Invalid arguments');
        }
        return _handleToolCall(requestId, name, arguments, caller: caller);
      default:
        return _replyError(
          requestId,
          -32601,
          'Method not implemented: $method',
        );
    }
  }

  Map<String, dynamic> _buildToolsList({
    required String cursor,
    required bool withUserTools,
  }) {
    final tools = <Map<String, dynamic>>[];
    var foundCursor = cursor.isEmpty;
    for (final tool in _tools) {
      if (!foundCursor) {
        if (tool.name == cursor) {
          foundCursor = true;
        } else {
          continue;
        }
      }
      if (!withUserTools && tool.userOnly) {
        continue;
      }
      tools.add(tool.toJson());
    }
    return <String, dynamic>{'tools': tools};
  }

  Future<Map<String, dynamic>> _handleToolCall(
    Object id,
    String name,
    Map<String, dynamic>? arguments, {
    required McpCallerType caller,
  }) async {
    final tool = _tools.where((tool) => tool.name == name).firstOrNull;
    if (tool == null) {
      return _replyError(id, -32601, 'Unknown tool: $name');
    }
    if (tool.userOnly && !caller.canAccessUserOnly) {
      return _replyError(id, -32001, 'Unauthorized tool access: $name');
    }

    Map<String, Object?> bound;
    try {
      bound = _bindArguments(tool, arguments ?? <String, dynamic>{});
    } catch (error) {
      return _replyError(
        id,
        -32602,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }

    try {
      final value = await tool.callback(bound);
      return _replyResult(id, _wrapToolResult(value));
    } catch (error) {
      return _replyError(
        id,
        -32603,
        error.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Map<String, Object?> _bindArguments(
    McpTool tool,
    Map<String, dynamic> arguments,
  ) {
    final bound = <String, Object?>{};
    for (final property in tool.properties) {
      final rawValue = arguments[property.name];
      if (rawValue == null) {
        if (property.hasDefault) {
          bound[property.name] = property.defaultValue;
          continue;
        }
        throw Exception('Missing valid argument: ${property.name}');
      }
      switch (property.type) {
        case McpPropertyType.boolean:
          if (rawValue is! bool) {
            throw Exception('Missing valid argument: ${property.name}');
          }
          bound[property.name] = rawValue;
          break;
        case McpPropertyType.integer:
          final value = rawValue is int
              ? rawValue
              : rawValue is num && rawValue == rawValue.toInt()
              ? rawValue.toInt()
              : null;
          if (value == null) {
            throw Exception('Missing valid argument: ${property.name}');
          }
          if (property.minValue != null && value < property.minValue!) {
            throw Exception(
              'Value is below minimum allowed: ${property.minValue}',
            );
          }
          if (property.maxValue != null && value > property.maxValue!) {
            throw Exception(
              'Value exceeds maximum allowed: ${property.maxValue}',
            );
          }
          bound[property.name] = value;
          break;
        case McpPropertyType.string:
          if (rawValue is! String) {
            throw Exception('Missing valid argument: ${property.name}');
          }
          bound[property.name] = rawValue;
          break;
      }
    }
    return bound;
  }

  Map<String, dynamic> _wrapToolResult(Object? value) {
    String text;
    if (value is bool) {
      text = value ? 'true' : 'false';
    } else if (value is num) {
      text = value.toString();
    } else if (value is String) {
      text = value;
    } else if (value is Map || value is List) {
      text = jsonEncode(value);
    } else if (value == null) {
      text = 'null';
    } else {
      text = value.toString();
    }
    return <String, dynamic>{
      'content': <Map<String, dynamic>>[
        <String, dynamic>{'type': 'text', 'text': text},
      ],
      'isError': false,
    };
  }

  Map<String, dynamic> _replyResult(Object? id, Object result) {
    return <String, dynamic>{'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic> _replyError(Object? id, int code, String message) {
    return <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, dynamic>{'code': code, 'message': message},
    };
  }

  Object? _normalizeRequestId(Object? value) {
    if (value is num || value is String) {
      return value;
    }
    return null;
  }

  Map<String, dynamic>? _asStringKeyedMap(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  void _registerTools() {
    addTool(
      McpTool(
        name: 'self.get_device_status',
        description:
            '[VI] Mục đích: Lấy trạng thái thiết bị theo thời gian thực (âm '
            'lượng, nền tảng, thông tin hệ thống). Dùng tool này trước khi '
            'thực hiện lệnh điều khiển để có giá trị hiện tại.\n'
            'Cách dùng: gọi không cần tham số.\n'
            'Kết quả: JSON chứa trạng thái thiết bị.\n'
            '[EN] Purpose: Get real-time device status (speaker volume, '
            'platform, and system-related state). Call this before control '
            'commands to read current values.\n'
            'Usage: call without arguments.\n'
            'Return: JSON object with device status.',
        properties: const <McpProperty>[],
        callback: (_) => _controller.getDeviceStatus(),
      ),
    );

    addTool(
      McpTool(
        name: 'self.audio_speaker.set_volume',
        description:
            '[VI] Mục đích: Đặt âm lượng loa thiết bị. Nên gọi '
            '`self.get_device_status` trước để biết giá trị hiện tại.\n'
            'Cách dùng: truyền `volume` (0-100).\n'
            'Kết quả: `true/false` cho biết đặt âm lượng thành công hay không.\n'
            '[EN] Purpose: Set device speaker volume. It is recommended to '
            'call `self.get_device_status` first to know current volume.\n'
            'Usage: provide `volume` (0-100).\n'
            'Return: `true/false` indicating whether the operation succeeded.',
        properties: const <McpProperty>[
          McpProperty.integer('volume', min: 0, max: 100),
        ],
        callback: (args) async {
          final volume = args['volume'] as int? ?? 0;
          return _controller.setSpeakerVolume(volume);
        },
      ),
    );

    addTool(
      McpTool(
        name: 'self.text.normalize_brand_name',
        description:
            '[VI] Mục đích: Chuẩn hoá tên thương hiệu từ lỗi STT/gõ phím '
            '(vd: "tranh viet", "chai vi", "tra vi" -> "Chanh Viet/Chavi").\n'
            'Cách dùng: truyền `text` cần chuẩn hoá.\n'
            'Kết quả: JSON gồm `original`, `normalized`, `changed`.\n'
            '[EN] Purpose: Normalize brand names from STT/typing errors '
            '(e.g., "tranh viet", "chai vi", "tra vi" -> '
            '"Chanh Viet/Chavi").\n'
            'Usage: provide input `text`.\n'
            'Return: JSON with `original`, `normalized`, and `changed`.',
        properties: const <McpProperty>[McpProperty.string('text')],
        callback: (args) {
          final rawText = args['text'] as String? ?? '';
          final normalized = _normalizeBrandName(rawText);
          return <String, dynamic>{
            'original': rawText,
            'normalized': normalized,
            'changed': normalized != rawText,
          };
        },
      ),
    );

    addTool(
      McpTool(
        name: 'self.guard.blocked_phrase_check',
        description:
            '[VI] Mục đích: Kiểm tra câu STT có thuộc nhóm ngoài phạm vi hỗ '
            'trợ hay không (ví dụ nội dung không liên quan đến sản phẩm/dịch vụ). '
            'Khi bị chặn, trả về câu phản hồi an toàn để yêu cầu người dùng nói lại.\n'
            'Cách dùng: truyền `text`.\n'
            'Kết quả: JSON gồm `blocked`, `response`, `reason`.\n'
            '[EN] Purpose: Check whether an STT sentence is out-of-scope '
            '(for example unrelated requests). If blocked, return a safe '
            'fallback response asking user to restate the question.\n'
            'Usage: provide `text`.\n'
            'Return: JSON with `blocked`, `response`, and `reason`.',
        properties: const <McpProperty>[McpProperty.string('text')],
        callback: (args) {
          final rawText = args['text'] as String? ?? '';
          final folded = _normalizeForGuard(rawText);
          final blockedPatterns = <String>[
            'la la school',
            'lalaschool',
            'subscribe',
            'hay subscribe',
            'sub kenh',
            'hay sub',
            'subcribe',
            'dang ky kenh',
            'dang ky',
          ];
          final blocked = blockedPatterns.any(folded.contains);
          if (!blocked) {
            return <String, dynamic>{
              'blocked': false,
              'response': '',
              'reason': 'ok',
            };
          }
          return <String, dynamic>{
            'blocked': true,
            'response':
                'Xin loi, minh nghe khong ro. Ban vui long noi lai giup minh nhe.',
            'reason': 'out_of_scope_phrase',
          };
        },
      ),
    );

    addTool(
      McpTool(
        name: 'self.knowledge.search',
        description:
            '[VI] BƯỚC BẮT BUỘC CHO TRI THỨC: Với câu hỏi về sản phẩm, thương '
            'hiệu, thành phần, xuất xứ, giá, chính sách..., phải gọi tool này '
            'trước khi trả lời. Tool tìm trong tài liệu đã tải lên và trả kết '
            'quả liên quan.\n'
            'Cách dùng: truyền `query` (nội dung cần tìm), `top_k` (1-10, '
            'mặc định 3).\n'
            'Kết quả: JSON gồm `matched`, `results[]` (name, score, snippet, '
            'field_hits, title, doc_type, content, characters, updated_at).\n'
            '[EN] MANDATORY KNOWLEDGE STEP: For product/brand/component/'
            'origin/pricing/policy questions, call this tool before replying. '
            'It searches uploaded documents and returns relevant matches.\n'
            'Usage: provide `query`, optional `top_k` (1-10, default 3).\n'
            'Return: JSON with `matched` and `results[]` '
            '(name, score, snippet, field_hits, title, doc_type, content, '
            'characters, updated_at).',
        properties: const <McpProperty>[
          McpProperty.string('query'),
          McpProperty.integer('top_k', defaultInt: 3, min: 1, max: 10),
        ],
        callback: (args) async {
          final query = (args['query'] as String? ?? '').trim();
          if (query.isEmpty) {
            throw Exception('Missing valid argument: query');
          }
          final topK = args['top_k'] as int? ?? 3;
          final results = await _knowledgeBase.search(query, topK: topK);
          return <String, dynamic>{
            'query': query,
            'matched': results.length,
            'results': results,
          };
        },
      ),
    );

    addTool(
      McpTool(
        name: 'self.knowledge.search_images',
        description:
            '[VI] Mục đích: Tìm ảnh liên quan theo truy vấn tri thức. Tool sẽ '
            'tìm tài liệu khớp bằng `self.knowledge.search`, sau đó gom ảnh đã '
            'upload theo các tài liệu đó.\n'
            'Cách dùng: truyền `query`, tùy chọn `top_k` (1-10, mặc định 3), '
            '`max_images` (1-20, mặc định theo cấu hình app).\n'
            'Kết quả: JSON gồm `matched_docs` và `images[]` '
            '(id, doc_name, file_name, mime_type, bytes, created_at, url, score).\n'
            '[EN] Purpose: Search related images by knowledge query. The tool '
            'first runs `self.knowledge.search`, then collects uploaded images '
            'from matched documents.\n'
            'Usage: provide `query`, optional `top_k` (1-10, default 3), '
            '`max_images` (1-20, default from app config).\n'
            'Return: JSON with `matched_docs` and `images[]` '
            '(id, doc_name, file_name, mime_type, bytes, created_at, url, score).',
        properties: <McpProperty>[
          const McpProperty.string('query'),
          const McpProperty.integer('top_k', defaultInt: 3, min: 1, max: 10),
          McpProperty.integer(
            'max_images',
            defaultInt: AppConfig.chatRelatedImagesMaxCount,
            min: 1,
            max: 20,
          ),
        ],
        callback: (args) async {
          final query = (args['query'] as String? ?? '').trim();
          if (query.isEmpty) {
            throw Exception('Missing valid argument: query');
          }
          final topK = (args['top_k'] as int? ?? 3).clamp(1, 10);
          final maxImages =
              (args['max_images'] as int? ??
                      AppConfig.chatRelatedImagesMaxCount)
                  .clamp(1, 20);

          final matches = await _knowledgeBase.search(query, topK: topK);
          if (matches.isEmpty) {
            return <String, dynamic>{
              'query': query,
              'matched_docs': 0,
              'matched_docs_with_images': 0,
              'images': const <Map<String, Object?>>[],
            };
          }
          final foldedQuery = LocalKnowledgeBase._foldForSearch(query);
          final intentTokens = LocalKnowledgeBase._tokenize(foldedQuery);
          final intent = LocalKnowledgeBase._analyzeSearchIntent(
            foldedQuery: foldedQuery,
            tokens: intentTokens,
          );
          final topScore = (matches.first['score'] as num?)?.toInt() ?? 0;
          final topDocType = (matches.first['doc_type'] ?? '')
              .toString()
              .trim()
              .toLowerCase();
          final companyLike = <String>{'company_profile', 'info'};
          final productLike = <String>{'product'};
          final prefersCompanyLike =
              intent.preferredDocTypes.any(companyLike.contains) &&
              !intent.preferredDocTypes.any(productLike.contains) &&
              companyLike.contains(topDocType);
          final prefersProductLike =
              intent.preferredDocTypes.any(productLike.contains) &&
              !intent.preferredDocTypes.any(companyLike.contains) &&
              productLike.contains(topDocType);
          final filteredMatches = matches
              .where((row) {
                final rowDocType = (row['doc_type'] ?? '')
                    .toString()
                    .trim()
                    .toLowerCase();
                final rowScore = (row['score'] as num?)?.toInt() ?? 0;
                if (prefersCompanyLike) {
                  if (companyLike.contains(rowDocType)) {
                    return true;
                  }
                  return rowScore >= topScore - 12;
                }
                if (prefersProductLike) {
                  if (productLike.contains(rowDocType) ||
                      rowDocType == 'info') {
                    return true;
                  }
                  return rowScore >= topScore - 12;
                }
                return true;
              })
              .toList(growable: false);

          var normalizedQuery = _normalizeForGuard(query);
          normalizedQuery = normalizedQuery.replaceAll(
            RegExp(r'\bchabi\b', caseSensitive: false),
            'chavi',
          );
          const imageQueryStopwords = <String>{
            'cho',
            'toi',
            've',
            'thong',
            'tin',
            'hinh',
            'anh',
            'xem',
            'san',
            'pham',
            'la',
            'co',
            'nhung',
          };
          final queryTokens = normalizedQuery
              .split(RegExp(r'\s+'))
              .where(
                (token) =>
                    token.length >= 2 && !imageQueryStopwords.contains(token),
              )
              .toSet();

          final imageStore = await _getImageStore();
          final imagesByDoc = <String, Map<String, Map<String, Object?>>>{};
          for (final row in filteredMatches) {
            final docName = (row['name'] ?? '').toString().trim();
            if (docName.isEmpty) {
              continue;
            }
            final score = (row['score'] as num?)?.toInt() ?? 0;
            final titleRaw = (row['title'] ?? docName).toString();
            var normalizedTitle = _normalizeForGuard(titleRaw);
            normalizedTitle = normalizedTitle.replaceAll(
              RegExp(r'\bchabi\b', caseSensitive: false),
              'chavi',
            );
            final titleTokenHits = queryTokens
                .where((token) => normalizedTitle.contains(token))
                .length;
            final fieldHitsRaw = row['field_hits'];
            final fieldHits = fieldHitsRaw is List
                ? fieldHitsRaw.map((item) => item.toString()).toSet()
                : const <String>{};
            final scoreBoost =
                (titleTokenHits * 12) +
                (fieldHits.contains('title') ? 20 : 0) +
                (fieldHits.contains('aliases') ? 12 : 0) +
                (fieldHits.contains('keywords') ? 8 : 0);
            final effectiveScore = score + scoreBoost;
            final content = (row['content'] ?? '').toString().trim();
            final sections = LocalKnowledgeBase._parseKdocSections(content);
            final docId = LocalKnowledgeBase._sectionOrEmpty(
              sections,
              'DOC_ID',
            );
            final images = await _listImagesForDocumentReferences(
              imageStore,
              <String>[docName, titleRaw, docId],
              limit: maxImages * 3,
              expandReferences: false,
            );
            final resolvedDocName = images.isNotEmpty
                ? (images.first['doc_name'] ?? docName).toString().trim()
                : docName;
            final byIdForDoc = imagesByDoc.putIfAbsent(
              resolvedDocName,
              () => <String, Map<String, Object?>>{},
            );
            for (final item in images) {
              final imageId = (item['id'] ?? '').toString().trim();
              if (imageId.isEmpty) {
                continue;
              }
              final entry = <String, Object?>{
                ...item,
                'score': effectiveScore,
                'source_doc_score': score,
                'url':
                    '/api/documents/image/content?id=${Uri.encodeQueryComponent(imageId)}',
              };
              final existing = byIdForDoc[imageId];
              final existingScore = (existing?['score'] as num?)?.toInt() ?? -1;
              if (existing == null || effectiveScore > existingScore) {
                byIdForDoc[imageId] = entry;
              }
            }
          }

          List<Map<String, Object?>> bestSet = const <Map<String, Object?>>[];
          var bestSetScore = -1;
          for (final entry in imagesByDoc.entries) {
            final ranked = entry.value.values.toList(growable: false)
              ..sort((a, b) {
                final byScore = ((b['score'] as num?)?.toInt() ?? 0).compareTo(
                  (a['score'] as num?)?.toInt() ?? 0,
                );
                if (byScore != 0) {
                  return byScore;
                }
                final aCreated = (a['created_at'] ?? '').toString();
                final bCreated = (b['created_at'] ?? '').toString();
                return bCreated.compareTo(aCreated);
              });
            if (ranked.isEmpty) {
              continue;
            }
            final topImageScore = (ranked.first['score'] as num?)?.toInt() ?? 0;
            final totalImageScore = ranked.fold<int>(
              0,
              (sum, item) => sum + ((item['score'] as num?)?.toInt() ?? 0),
            );
            final setScore =
                (topImageScore * 1000) + totalImageScore + ranked.length;
            if (setScore > bestSetScore) {
              bestSetScore = setScore;
              bestSet = ranked.take(maxImages).toList(growable: false);
            }
          }
          return <String, dynamic>{
            'query': query,
            'matched_docs': filteredMatches.length,
            'matched_docs_with_images': imagesByDoc.length,
            'images': bestSet,
          };
        },
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.get_kdoc_schema',
        description:
            '[VI] Mục đích: Lấy schema chuẩn KDOC v1 dùng cho kho tri thức, '
            'bao gồm danh sách section, ý nghĩa từng section, thứ tự gợi ý '
            'và section khuyến nghị theo từng `DOC_TYPE`.\n'
            'Cách dùng: gọi không cần tham số.\n'
            'Kết quả: JSON gồm `format`, `required_sections`, `section_order`, '
            '`sections`, `doc_types`.\n'
            '[EN] Purpose: Get the canonical KDOC v1 schema for knowledge '
            'documents, including sections, meanings, recommended order, and '
            'doc-type-specific section guidance.\n'
            'Usage: call without arguments.\n'
            'Return: JSON with `format`, `required_sections`, '
            '`section_order`, `sections`, and `doc_types`.',
        properties: const <McpProperty>[],
        callback: (_) async => LocalKnowledgeBase.kdocSchema(),
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.get_system_info',
        description:
            '[VI] Mục đích: Lấy thông tin hệ thống của thiết bị (OS, '
            'version...).\n'
            'Cách dùng: gọi không cần tham số.\n'
            'Kết quả: JSON thông tin hệ thống.\n'
            '[EN] Purpose: Get system-level information (OS, version, etc.).\n'
            'Usage: call without arguments.\n'
            'Return: JSON with system information.',
        properties: const <McpProperty>[],
        callback: (_) => _controller.getSystemInfo(),
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.upload_text',
        description:
            '[VI] Mục đích: Tải nội dung văn bản trực tiếp vào kho tri thức '
            '(thêm mới/cập nhật theo tên tài liệu).\n'
            'Cách dùng: truyền `name` (tên tài liệu), `text` theo chuẩn '
            '`KDOC v1`. Để biết section chuẩn và section khuyến nghị theo '
            'từng `DOC_TYPE`, gọi `self.knowledge.get_kdoc_schema` trước.\n'
            'Kết quả: JSON gồm trạng thái upload, metadata tài liệu và tổng '
            'số tài liệu.\n'
            '[EN] Purpose: Upload raw text to the knowledge base '
            '(insert/update by document name).\n'
            'Usage: provide `name` (document name) and `text` in `KDOC v1` '
            'schema. Call `self.knowledge.get_kdoc_schema` first for the '
            'canonical section guide.\n'
            'Return: JSON with upload status, document metadata, and total '
            'document count.',
        properties: const <McpProperty>[
          McpProperty.string('name'),
          McpProperty.string('text'),
        ],
        callback: (args) async {
          final name = (args['name'] as String? ?? '').trim();
          final text = (args['text'] as String? ?? '').trim();
          if (name.isEmpty) {
            throw Exception('Missing valid argument: name');
          }
          if (text.isEmpty) {
            throw Exception('Missing valid argument: text');
          }
          final meta = await _knowledgeBase.upsertDocument(
            name: name,
            content: text,
          );
          return <String, dynamic>{
            'uploaded': true,
            'document': meta,
            'documents_total': _knowledgeBase.count,
          };
        },
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.upload_file',
        description:
            '[VI] Mục đích: Tải tài liệu từ đường dẫn file local vào kho tri '
            'thức. Hỗ trợ file văn bản theo chuẩn KDOC v1 để tìm kiếm theo '
            'field sau này. Có thể gọi `self.knowledge.get_kdoc_schema` để '
            'xem schema section chuẩn trước khi import.\n'
            'Cách dùng: truyền `path` (bắt buộc), `name` (tuỳ chọn - nếu '
            'bỏ trống sẽ lấy tên file).\n'
            'Kết quả: JSON gồm trạng thái upload, metadata tài liệu và tổng '
            'số tài liệu.\n'
            '[EN] Purpose: Upload a local file into the knowledge base. '
            'Supports KDOC v1 text-like files for structured search. Use '
            '`self.knowledge.get_kdoc_schema` to inspect canonical sections '
            'before import.\n'
            'Usage: provide required `path`, optional `name` (defaults to '
            'file name if empty).\n'
            'Return: JSON with upload status, document metadata, and total '
            'document count.',
        properties: const <McpProperty>[
          McpProperty.string('path'),
          McpProperty.string('name', defaultString: ''),
        ],
        callback: (args) async {
          final path = (args['path'] as String? ?? '').trim();
          var name = (args['name'] as String? ?? '').trim();
          if (path.isEmpty) {
            throw Exception('Missing valid argument: path');
          }
          if (name.isEmpty) {
            name = LocalKnowledgeBase.fileNameFromPath(path);
          }
          final meta = await _knowledgeBase.uploadFromFile(
            path: path,
            name: name,
          );
          return <String, dynamic>{
            'uploaded': true,
            'document': meta,
            'documents_total': _knowledgeBase.count,
          };
        },
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.list_documents',
        description:
            '[VI] Mục đích: Liệt kê danh sách tài liệu đã tải lên cùng '
            'metadata.\n'
            'Cách dùng: gọi không cần tham số.\n'
            'Kết quả: JSON gồm `count` và `documents[]` '
            '(name, characters, updated_at).\n'
            '[EN] Purpose: List all uploaded knowledge documents with metadata.\n'
            'Usage: call without arguments.\n'
            'Return: JSON with `count` and `documents[]` '
            '(name, characters, updated_at).',
        properties: const <McpProperty>[],
        callback: (_) async {
          final documents = await _knowledgeBase.listDocuments();
          return <String, dynamic>{
            'count': documents.length,
            'documents': documents,
          };
        },
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.list_images',
        description:
            '[VI] Mục đích: Liệt kê danh sách ảnh đã tải lên từ kho tri thức. '
            'Có thể lọc theo `doc_name` và giới hạn số lượng bằng `limit`.\n'
            'Cách dùng: gọi không cần tham số hoặc truyền `doc_name`, `limit`.\n'
            'Kết quả: JSON gồm `count` và `images[]` '
            '(id, doc_name, file_name, mime_type, bytes, created_at, url).\n'
            '[EN] Purpose: List uploaded knowledge images. Optional '
            '`doc_name` filter and `limit` for result size.\n'
            'Usage: call without arguments or provide `doc_name`, `limit`.\n'
            'Return: JSON with `count` and `images[]` '
            '(id, doc_name, file_name, mime_type, bytes, created_at, url).',
        properties: <McpProperty>[
          const McpProperty.string('doc_name', defaultString: ''),
          McpProperty.integer(
            'limit',
            defaultInt: AppConfig.homeCarouselMaxImages,
            min: 1,
            max: 50,
          ),
        ],
        callback: (args) async {
          final docName = (args['doc_name'] as String? ?? '').trim();
          final limit =
              (args['limit'] as int? ?? AppConfig.homeCarouselMaxImages).clamp(
                1,
                50,
              );
          final imageStore = await _getImageStore();
          final resolvedReferences = docName.isEmpty
              ? const <String>[]
              : await _knowledgeBase.resolveImageLookupReferences(docName);
          final images = docName.isEmpty
              ? await imageStore.listAllImages()
              : await _listImagesForDocumentReferences(
                  imageStore,
                  resolvedReferences.isEmpty
                      ? <String>[docName]
                      : resolvedReferences,
                  limit: limit,
                  expandReferences: false,
                );
          final enriched = <Map<String, Object?>>[];
          for (final item in images.take(limit)) {
            final id = (item['id'] ?? '').toString().trim();
            if (id.isEmpty) {
              continue;
            }
            enriched.add(<String, Object?>{
              ...item,
              'url':
                  '/api/documents/image/content?id=${Uri.encodeQueryComponent(id)}',
            });
          }
          return <String, dynamic>{
            'count': images.length,
            if (docName.isNotEmpty)
              'doc_name': resolvedReferences.isNotEmpty
                  ? resolvedReferences.first
                  : docName,
            'images': enriched,
          };
        },
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.get_document',
        description:
            '[VI] Mục đích: Lấy nội dung đầy đủ của một tài liệu theo tên.\n'
            'Cách dùng: truyền `name` (tên tài liệu).\n'
            'Kết quả: JSON gồm metadata và `content` đầy đủ.\n'
            '[EN] Purpose: Retrieve full content of a document by name.\n'
            'Usage: provide `name` (document name).\n'
            'Return: JSON with metadata and full `content`.',
        properties: const <McpProperty>[McpProperty.string('name')],
        callback: (args) async {
          final name = (args['name'] as String? ?? '').trim();
          if (name.isEmpty) {
            throw Exception('Missing valid argument: name');
          }
          final doc = await _knowledgeBase.getDocument(name);
          if (doc == null) {
            throw Exception('Document not found: $name');
          }
          return doc;
        },
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.delete_document',
        description:
            '[VI] Mục đích: Xóa một tài liệu theo tên.\n'
            'Cách dùng: truyền `name` (tên tài liệu).\n'
            'Kết quả: JSON gồm `deleted` và metadata tài liệu (nếu có).\n'
            '[EN] Purpose: Delete a document by name.\n'
            'Usage: provide `name` (document name).\n'
            'Return: JSON with `deleted` and document metadata (if any).',
        properties: const <McpProperty>[McpProperty.string('name')],
        callback: (args) async {
          final name = (args['name'] as String? ?? '').trim();
          if (name.isEmpty) {
            throw Exception('Missing valid argument: name');
          }
          final imageStore = await _getImageStore();
          final removed = await _knowledgeBase.deleteDocument(name);
          final removedImages = await imageStore.clearDocument(name);
          return <String, dynamic>{
            'deleted': removed != null,
            'document': removed,
            'removed_images': removedImages,
            'documents_total': _knowledgeBase.count,
          };
        },
        userOnly: true,
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.knowledge.clear',
        description:
            '[VI] Mục đích: Xoá toàn bộ tài liệu trong kho tri thức.\n'
            'Cách dùng: gọi không cần tham số.\n'
            'Kết quả: JSON gồm `cleared=true`, số lượng tài liệu đã xoá '
            '(`removed`) và số ảnh đã xoá (`removed_images`).\n'
            '[EN] Purpose: Remove all documents from the knowledge base.\n'
            'Usage: call without arguments.\n'
            'Return: JSON with `cleared=true`, removed document count '
            '(`removed`) and removed image count (`removed_images`).',
        properties: const <McpProperty>[],
        callback: (_) async {
          final imageStore = await _getImageStore();
          final removed = await _knowledgeBase.clear();
          final removedImages = await imageStore.clearAll();
          return <String, dynamic>{
            'cleared': true,
            'removed': removed,
            'removed_images': removedImages,
          };
        },
        userOnly: true,
      ),
    );
  }

  void addTool(McpTool tool) {
    if (_tools.any((existing) => existing.name == tool.name)) {
      return;
    }
    _tools.add(tool);
  }

  void addUserOnlyTool(McpTool tool) {
    addTool(tool);
  }

  String _normalizeBrandName(String text) {
    var output = text;
    final replacements = <RegExp, String>{
      RegExp(r'\btranh\s+việt\b', caseSensitive: false): 'Chanh Việt',
      RegExp(r'\btranh\s+viet\b', caseSensitive: false): 'Chanh Việt',
      RegExp(r'\bchanh\s+viet\b', caseSensitive: false): 'Chanh Việt',
      RegExp(r'\btranhviet\b', caseSensitive: false): 'Chanh Việt',
      RegExp(r'\bchanhviet\b', caseSensitive: false): 'Chanh Việt',
    };

    for (final entry in replacements.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }

  String _normalizeForGuard(String input) {
    return input
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ầ', 'a')
        .replaceAll('ấ', 'a')
        .replaceAll('ậ', 'a')
        .replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('ằ', 'a')
        .replaceAll('ắ', 'a')
        .replaceAll('ặ', 'a')
        .replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ề', 'e')
        .replaceAll('ế', 'e')
        .replaceAll('ệ', 'e')
        .replaceAll('ể', 'e')
        .replaceAll('ễ', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ồ', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ờ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ử', 'u')
        .replaceAll('ữ', 'u')
        .replaceAll('ỳ', 'y')
        .replaceAll('ý', 'y')
        .replaceAll('ỵ', 'y')
        .replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<DocumentImageStore> _getImageStore() {
    final existing = _imageStoreFuture;
    if (existing != null) {
      return existing;
    }
    final created = _createImageStore();
    _imageStoreFuture = created;
    return created.then(
      (store) => store,
      onError: (Object error, StackTrace stackTrace) {
        if (identical(_imageStoreFuture, created)) {
          _imageStoreFuture = null;
        }
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  Future<DocumentImageStore> _createImageStore() async {
    if (_imageStoreLoader != null) {
      return _imageStoreLoader!.call();
    }
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

  Future<List<Map<String, Object?>>> _listImagesForDocumentReferences(
    DocumentImageStore imageStore,
    Iterable<String> references, {
    required int limit,
    bool expandReferences = true,
  }) async {
    final orderedReferences = expandReferences
        ? await _resolveDocumentImageReferences(references)
        : _dedupeDocumentReferences(references);
    if (orderedReferences.isEmpty) {
      return <Map<String, Object?>>[];
    }

    final imagesById = <String, Map<String, Object?>>{};
    for (final reference in orderedReferences) {
      if (imagesById.length >= limit) {
        break;
      }
      final images = await imageStore.listImagesByDocument(reference);
      for (final item in images) {
        final id = (item['id'] ?? '').toString().trim();
        if (id.isEmpty || imagesById.containsKey(id)) {
          continue;
        }
        imagesById[id] = item;
        if (imagesById.length >= limit) {
          break;
        }
      }
    }
    return imagesById.values.toList(growable: false);
  }

  List<String> _dedupeDocumentReferences(Iterable<String> references) {
    final ordered = <String>[];
    final seen = <String>{};
    for (final reference in references) {
      final trimmed = reference.trim();
      if (trimmed.isEmpty || !seen.add(trimmed)) {
        continue;
      }
      ordered.add(trimmed);
    }
    return ordered;
  }

  Future<List<String>> _resolveDocumentImageReferences(
    Iterable<String> references,
  ) async {
    final ordered = _dedupeDocumentReferences(references);
    final seen = ordered.toSet();

    final querySet = ordered.toList(growable: false);
    for (final reference in querySet) {
      final matches = await _knowledgeBase.search(reference, topK: 4);
      final scoredCandidates = <({String value, int score})>[];

      void addCandidate(String value, int baseScore) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) {
          return;
        }
        final score = baseScore + _documentReferenceScore(reference, trimmed);
        if (score <= 0) {
          return;
        }
        scoredCandidates.add((value: trimmed, score: score));
      }

      for (final row in matches) {
        final rowScore = (row['score'] as num?)?.toInt() ?? 0;
        final name = (row['name'] ?? '').toString().trim();
        final title = (row['title'] ?? '').toString().trim();
        addCandidate(name, rowScore + 40);
        addCandidate(title, rowScore + 44);

        final content = (row['content'] ?? '').toString().trim();
        final sections = LocalKnowledgeBase._parseKdocSections(content);
        final docId = LocalKnowledgeBase._sectionOrEmpty(sections, 'DOC_ID');
        addCandidate(docId, rowScore + 36);
      }

      scoredCandidates.sort((a, b) => b.score.compareTo(a.score));
      for (final candidate in scoredCandidates) {
        final trimmed = candidate.value.trim();
        if (trimmed.isEmpty || candidate.score < 160 || !seen.add(trimmed)) {
          continue;
        }
        ordered.add(trimmed);
      }
    }

    return ordered;
  }

  int _documentReferenceScore(String reference, String candidate) {
    final foldedReference = LocalKnowledgeBase._foldForSearch(reference.trim());
    final foldedCandidate = LocalKnowledgeBase._foldForSearch(candidate.trim());
    if (foldedReference.isEmpty || foldedCandidate.isEmpty) {
      return 0;
    }

    final compactReference = LocalKnowledgeBase._compact(foldedReference);
    final compactCandidate = LocalKnowledgeBase._compact(foldedCandidate);
    final phrases = LocalKnowledgeBase._expandSearchPhrases(foldedReference);
    final tokens = <String>{
      for (final phrase in phrases) ...LocalKnowledgeBase._tokenize(phrase),
    };

    var score = 0;
    if (foldedCandidate == foldedReference ||
        compactCandidate == compactReference) {
      score += 120;
    }
    for (final phrase in phrases) {
      if (phrase.isEmpty) {
        continue;
      }
      if (foldedCandidate.contains(phrase)) {
        score += 36;
      }
      final compactPhrase = LocalKnowledgeBase._compact(phrase);
      if (compactPhrase.isNotEmpty &&
          compactCandidate.contains(compactPhrase)) {
        score += 20;
      }
    }
    for (final token in tokens) {
      if (foldedCandidate.contains(token)) {
        score += 6;
      }
    }
    return score;
  }
}

class McpTool {
  const McpTool({
    required this.name,
    required this.description,
    required this.properties,
    required this.callback,
    this.userOnly = false,
  });

  final String name;
  final String description;
  final List<McpProperty> properties;
  final FutureOr<Object?> Function(Map<String, Object?> args) callback;
  final bool userOnly;

  Map<String, dynamic> toJson() {
    final requiredProps = properties
        .where((property) => !property.hasDefault)
        .map((property) => property.name)
        .toList();
    final propertiesJson = <String, dynamic>{
      for (final property in properties) property.name: property.toJson(),
    };
    final inputSchema = <String, dynamic>{
      'type': 'object',
      'properties': propertiesJson,
    };
    if (requiredProps.isNotEmpty) {
      inputSchema['required'] = requiredProps;
    }
    final json = <String, dynamic>{
      'name': name,
      'description': description,
      'inputSchema': inputSchema,
    };
    if (userOnly) {
      json['annotations'] = <String, dynamic>{
        'audience': <String>['user'],
      };
    }
    return json;
  }
}

class KdocValidationResult {
  const KdocValidationResult({required this.isValid, required this.errors});

  final bool isValid;
  final List<String> errors;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'is_valid': isValid, 'errors': errors};
  }
}

class LocalKnowledgeBase {
  LocalKnowledgeBase({
    Future<Directory> Function()? documentsDirectoryResolver,
    Future<void> Function(File file, String contents)? storageWriter,
  }) : _documentsDirectoryResolver = documentsDirectoryResolver,
       _storageWriter = storageWriter;

  static const int _maxFileBytes = 5 * 1024 * 1024;
  static const String _storageFileName = 'knowledge_base.json';
  static const String _storageVersion = '1';
  static const String _kdocHeader = '=== KDOC:v1 ===';
  static const String _kdocFooter = '=== END_KDOC ===';
  static const Set<String> _requiredKdocSections = <String>{
    'DOC_ID',
    'DOC_TYPE',
    'TITLE',
    'ALIASES',
    'SUMMARY',
    'CONTENT',
    'LAST_UPDATED',
  };
  static const Set<String> _allowedDocTypes = <String>{
    'product',
    'faq',
    'policy',
    'info',
    'company_profile',
  };
  static const Set<String> _searchStopwords = <String>{
    'la',
    'va',
    'hoac',
    'nhung',
    'voi',
    'cho',
    'toi',
    'ban',
    'moi',
    'nay',
    'kia',
    'cua',
    'trong',
    'tren',
    'duoc',
    'khong',
    'co',
    've',
    'hay',
    'giup',
    'them',
    'thong',
    'tin',
    'nhe',
  };
  static const Set<String> _searchMetaSections = <String>{
    'DOC_ID',
    'DOC_TYPE',
    'TITLE',
    'ALIASES',
    'KEYWORDS',
    'SUMMARY',
    'LAST_UPDATED',
  };
  static const List<String> _kdocSectionOrder = <String>[
    'DOC_ID',
    'DOC_TYPE',
    'TITLE',
    'ALIASES',
    'KEYWORDS',
    'SUMMARY',
    'CONTENT',
    'CORE_PRODUCTS',
    'RAW_MATERIALS',
    'PROCESS',
    'FOOD_SAFETY',
    'MARKET',
    'SERVICES',
    'REGULATIONS',
    'USAGE',
    'DAY_VISIT',
    'STAY_PACKAGE',
    'FAQ',
    'SAFETY_NOTE',
    'LAST_UPDATED',
  ];
  final Map<String, _KnowledgeDocument> _documents =
      <String, _KnowledgeDocument>{};
  final Future<Directory> Function()? _documentsDirectoryResolver;
  final Future<void> Function(File file, String contents)? _storageWriter;
  Future<void>? _initFuture;
  File? _storageFile;

  int get count => _documents.length;

  static String fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final parts = normalized.split('/');
    return parts.isEmpty ? path : parts.last;
  }

  static KdocValidationResult validateKdocContent(String content) {
    final trimmed = content.trim();
    final sections = _parseKdocSections(trimmed);
    if (sections == null) {
      return const KdocValidationResult(
        isValid: false,
        errors: <String>[
          'Thiếu định dạng KDOC v1 hoặc marker đầu/cuối không hợp lệ.',
        ],
      );
    }

    final errors = <String>[];
    for (final key in _requiredKdocSections) {
      final value = sections[key]?.trim() ?? '';
      if (value.isEmpty) {
        errors.add('Thiếu mục bắt buộc [$key].');
      }
    }

    final docType = (sections['DOC_TYPE'] ?? '').trim().toLowerCase();
    if (docType.isNotEmpty && !_allowedDocTypes.contains(docType)) {
      errors.add(
        '[DOC_TYPE] không hợp lệ. Chỉ chấp nhận: '
        '${_allowedDocTypes.join(', ')}.',
      );
    }

    final lastUpdated = (sections['LAST_UPDATED'] ?? '').trim();
    if (lastUpdated.isNotEmpty && DateTime.tryParse(lastUpdated) == null) {
      errors.add('[LAST_UPDATED] phải là ngày hợp lệ (ISO-8601).');
    }

    final docId = (sections['DOC_ID'] ?? '').trim();
    if (docId.isNotEmpty && !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(docId)) {
      errors.add('[DOC_ID] chỉ được chứa chữ, số, `_`, `-`, `.`.');
    }

    return KdocValidationResult(
      isValid: errors.isEmpty,
      errors: List<String>.unmodifiable(errors),
    );
  }

  static Map<String, dynamic> kdocSchema() {
    return <String, dynamic>{
      'format': 'KDOC:v1',
      'header': _kdocHeader,
      'footer': _kdocFooter,
      'required_sections': _requiredKdocSections.toList(growable: false),
      'section_order': _kdocSectionOrder,
      'sections': <String, Map<String, Object?>>{
        'DOC_ID': <String, Object?>{
          'label': 'Mã tài liệu',
          'required': true,
          'multi_line': false,
          'purpose': 'Định danh duy nhất, ổn định theo thời gian.',
          'example': 'bot_chanh_chavi_400g',
        },
        'DOC_TYPE': <String, Object?>{
          'label': 'Loại tài liệu',
          'required': true,
          'multi_line': false,
          'purpose': 'Phân loại tài liệu để chọn section phù hợp.',
          'allowed_values': _allowedDocTypes.toList(growable: false),
          'example': 'product',
        },
        'TITLE': <String, Object?>{
          'label': 'Tiêu đề',
          'required': true,
          'multi_line': false,
          'purpose': 'Tên hiển thị chính thức của tài liệu.',
        },
        'ALIASES': <String, Object?>{
          'label': 'Tên gọi khác',
          'required': true,
          'multi_line': true,
          'purpose': 'Biến thể tên gọi để hỗ trợ tìm kiếm.',
        },
        'KEYWORDS': <String, Object?>{
          'label': 'Từ khóa',
          'required': false,
          'multi_line': true,
          'purpose': 'Từ khóa hỗ trợ retrieval theo ý định câu hỏi.',
        },
        'SUMMARY': <String, Object?>{
          'label': 'Tóm tắt',
          'required': true,
          'multi_line': true,
          'purpose': 'Tóm tắt ngắn gọn nhất của tài liệu.',
        },
        'CONTENT': <String, Object?>{
          'label': 'Nội dung chính',
          'required': true,
          'multi_line': true,
          'purpose': 'Thông tin cốt lõi, thường dưới dạng gạch đầu dòng.',
        },
        'CORE_PRODUCTS': <String, Object?>{
          'label': 'Sản phẩm / hạng mục chính',
          'required': false,
          'multi_line': true,
          'purpose': 'Danh mục sản phẩm chủ lực hoặc hạng mục chính.',
        },
        'RAW_MATERIALS': <String, Object?>{
          'label': 'Nguyên liệu',
          'required': false,
          'multi_line': true,
          'purpose': 'Nguồn nguyên liệu, vùng trồng, tiêu chuẩn đầu vào.',
        },
        'PROCESS': <String, Object?>{
          'label': 'Quy trình',
          'required': false,
          'multi_line': true,
          'purpose': 'Quy trình sản xuất, chế biến, kiểm soát chất lượng.',
        },
        'FOOD_SAFETY': <String, Object?>{
          'label': 'An toàn thực phẩm',
          'required': false,
          'multi_line': true,
          'purpose': 'Chứng nhận, tiêu chuẩn, kiểm định, OCOP, HACCP, FDA...',
        },
        'MARKET': <String, Object?>{
          'label': 'Thị trường & phân phối',
          'required': false,
          'multi_line': true,
          'purpose': 'Thị trường mục tiêu, kênh phân phối, xuất khẩu.',
        },
        'SERVICES': <String, Object?>{
          'label': 'Dịch vụ / lĩnh vực hoạt động',
          'required': false,
          'multi_line': true,
          'purpose': 'Dịch vụ cung cấp hoặc lĩnh vực hoạt động chính.',
        },
        'REGULATIONS': <String, Object?>{
          'label': 'Quy định / điều kiện',
          'required': false,
          'multi_line': true,
          'purpose': 'Quy định nội bộ, điều kiện hợp tác, lưu ý vận hành.',
        },
        'USAGE': <String, Object?>{
          'label': 'Cách dùng / liên hệ',
          'required': false,
          'multi_line': true,
          'purpose': 'Cách dùng sản phẩm hoặc thông tin liên hệ/hợp tác.',
        },
        'DAY_VISIT': <String, Object?>{
          'label': 'Gói trong ngày',
          'required': false,
          'multi_line': true,
          'purpose': 'Thông tin trải nghiệm trong ngày cho tài liệu du lịch.',
        },
        'STAY_PACKAGE': <String, Object?>{
          'label': 'Gói lưu trú',
          'required': false,
          'multi_line': true,
          'purpose': 'Thông tin lưu trú qua đêm, phòng/lều, tiện ích.',
        },
        'FAQ': <String, Object?>{
          'label': 'Hỏi đáp thường gặp',
          'required': false,
          'multi_line': true,
          'purpose': 'Cặp câu hỏi/trả lời ngắn để agent trích xuất nhanh.',
        },
        'SAFETY_NOTE': <String, Object?>{
          'label': 'Lưu ý an toàn / phạm vi thông tin',
          'required': false,
          'multi_line': true,
          'purpose': 'Lưu ý giới hạn nội dung, không suy diễn công dụng y tế.',
        },
        'LAST_UPDATED': <String, Object?>{
          'label': 'Ngày cập nhật',
          'required': true,
          'multi_line': false,
          'purpose': 'Ngày cập nhật ISO-8601, ví dụ 2026-02-08.',
        },
      },
      'doc_types': <String, Map<String, Object?>>{
        'product': <String, Object?>{
          'description': 'Tài liệu cho một sản phẩm cụ thể.',
          'recommended_sections': const <String>[
            'KEYWORDS',
            'USAGE',
            'FAQ',
            'SAFETY_NOTE',
          ],
        },
        'company_profile': <String, Object?>{
          'description': 'Hồ sơ doanh nghiệp hoặc thương hiệu.',
          'recommended_sections': const <String>[
            'CORE_PRODUCTS',
            'RAW_MATERIALS',
            'PROCESS',
            'FOOD_SAFETY',
            'MARKET',
            'SAFETY_NOTE',
          ],
        },
        'info': <String, Object?>{
          'description':
              'Tài liệu thông tin tổng hợp hoặc mô tả dịch vụ/địa điểm.',
          'recommended_sections': const <String>[
            'SERVICES',
            'DAY_VISIT',
            'STAY_PACKAGE',
            'REGULATIONS',
            'FAQ',
            'SAFETY_NOTE',
          ],
        },
        'faq': <String, Object?>{
          'description': 'Bộ câu hỏi thường gặp.',
          'recommended_sections': const <String>['FAQ', 'SAFETY_NOTE'],
        },
        'policy': <String, Object?>{
          'description': 'Chính sách và quy định áp dụng.',
          'recommended_sections': const <String>[
            'REGULATIONS',
            'FAQ',
            'SAFETY_NOTE',
          ],
        },
      },
    };
  }

  Future<Map<String, dynamic>> upsertDocument({
    required String name,
    required String content,
  }) async {
    await _ensureInitialized();
    final normalizedName = name.trim();
    final normalizedContent = content.trim();
    final validation = validateKdocContent(normalizedContent);
    if (!validation.isValid) {
      throw Exception('KDOC format invalid: ${validation.errors.join(' | ')}');
    }
    final now = DateTime.now();
    final doc = _KnowledgeDocument(
      name: normalizedName,
      rawContent: normalizedContent,
      foldedContent: _foldForSearch(normalizedContent),
      compactContent: _compact(_foldForSearch(normalizedContent)),
      updatedAt: now,
    );
    final previous = _documents[normalizedName];
    _documents[normalizedName] = doc;
    try {
      await _persist();
    } catch (_) {
      if (previous == null) {
        _documents.remove(normalizedName);
      } else {
        _documents[normalizedName] = previous;
      }
      rethrow;
    }
    return _toMeta(doc);
  }

  Future<Map<String, dynamic>> uploadFromFile({
    required String path,
    required String name,
  }) async {
    await _ensureInitialized();
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }
    final length = await file.length();
    if (length > _maxFileBytes) {
      throw Exception('File too large: $length bytes (max $_maxFileBytes)');
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw Exception('File is empty: $path');
    }
    final content = utf8.decode(bytes, allowMalformed: true).trim();
    if (content.isEmpty) {
      throw Exception('File has no readable text content: $path');
    }
    return upsertDocument(name: name, content: content);
  }

  Future<List<Map<String, dynamic>>> listDocuments() async {
    await _ensureInitialized();
    final docs = _documents.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return docs.map(_toMeta).toList();
  }

  Future<Map<String, dynamic>?> getDocument(String name) async {
    await _ensureInitialized();
    final key = name.trim();
    if (key.isEmpty) {
      return null;
    }
    final doc = _documents[key];
    if (doc == null) {
      return null;
    }
    return <String, dynamic>{..._toMeta(doc), 'content': doc.rawContent};
  }

  Future<Map<String, dynamic>?> deleteDocument(String name) async {
    await _ensureInitialized();
    final key = name.trim();
    if (key.isEmpty) {
      return null;
    }
    final doc = _documents.remove(key);
    if (doc == null) {
      return null;
    }
    try {
      await _persist();
    } catch (_) {
      _documents[key] = doc;
      rethrow;
    }
    return _toMeta(doc);
  }

  Future<int> clear() async {
    await _ensureInitialized();
    final removed = _documents.length;
    final backup = Map<String, _KnowledgeDocument>.from(_documents);
    _documents.clear();
    try {
      await _persist();
    } catch (_) {
      _documents
        ..clear()
        ..addAll(backup);
      rethrow;
    }
    return removed;
  }

  Future<List<String>> resolveImageLookupReferences(String reference) async {
    await _ensureInitialized();
    final trimmed = reference.trim();
    if (trimmed.isEmpty) {
      return <String>[];
    }

    final foldedReference = _foldForSearch(trimmed);
    final compactReference = _compact(foldedReference);
    final phrases = _expandSearchPhrases(foldedReference);
    final tokens = <String>{for (final phrase in phrases) ..._tokenize(phrase)};

    _KnowledgeDocument? bestDoc;
    var bestTitle = '';
    var bestDocId = '';
    var bestScore = 0;

    for (final doc in _documents.values) {
      final sections = _parseKdocSections(doc.rawContent);
      final title = _sectionOrEmpty(sections, 'TITLE');
      final docId = _sectionOrEmpty(sections, 'DOC_ID');
      final aliases = _splitList(_sectionOrEmpty(sections, 'ALIASES'));
      final candidates = <String>[
        doc.name,
        if (title.isNotEmpty) title,
        if (docId.isNotEmpty) docId,
        ...aliases,
      ];

      var docScore = 0;
      for (final candidate in candidates) {
        final foldedCandidate = _foldForSearch(candidate);
        final compactCandidate = _compact(foldedCandidate);
        if (foldedCandidate.isEmpty) {
          continue;
        }
        if (foldedCandidate == foldedReference ||
            compactCandidate == compactReference) {
          docScore = docScore < 300 ? 300 : docScore;
        }
        for (final phrase in phrases) {
          if (phrase.isEmpty) {
            continue;
          }
          if (foldedCandidate.contains(phrase)) {
            docScore += 40;
          }
          final compactPhrase = _compact(phrase);
          if (compactPhrase.isNotEmpty &&
              compactCandidate.contains(compactPhrase)) {
            docScore += 24;
          }
        }
        for (final token in tokens) {
          if (foldedCandidate.contains(token)) {
            docScore += 8;
          }
        }
      }

      if (docScore > bestScore) {
        bestScore = docScore;
        bestDoc = doc;
        bestTitle = title;
        bestDocId = docId;
      }
    }

    if (bestDoc == null || bestScore < 40) {
      return <String>[trimmed];
    }

    final ordered = <String>[];
    final seen = <String>{};
    void addReference(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || !seen.add(normalized)) {
        return;
      }
      ordered.add(normalized);
    }

    addReference(bestTitle);
    addReference(bestDoc.name);
    addReference(bestDocId);
    addReference(trimmed);
    return ordered;
  }

  Future<List<Map<String, dynamic>>> search(
    String query, {
    required int topK,
  }) async {
    await _ensureInitialized();
    final foldedQuery = _foldForSearch(query.trim());
    if (foldedQuery.isEmpty) {
      return <Map<String, dynamic>>[];
    }
    final phrases = _expandSearchPhrases(foldedQuery);
    final compactPhrases = phrases.map(_compact).toSet();
    final tokens = <String>{for (final phrase in phrases) ..._tokenize(phrase)};
    final intent = _analyzeSearchIntent(
      foldedQuery: foldedQuery,
      tokens: tokens,
    );

    final matches =
        <
          ({
            int score,
            double coverageRatio,
            int matchedTokens,
            bool exactMatch,
            _KnowledgeDocument doc,
            String snippet,
            List<String> fieldHits,
            List<String> matchReasons,
            String title,
            String docType,
            String summary,
            String usage,
            String safetyNote,
            bool structured,
          })
        >[];
    for (final doc in _documents.values) {
      final sections = _parseKdocSections(doc.rawContent);
      final structured =
          sections != null && validateKdocContent(doc.rawContent).isValid;

      final title = _sectionOrEmpty(sections, 'TITLE').isEmpty
          ? doc.name
          : _sectionOrEmpty(sections, 'TITLE');
      final docType = _sectionOrEmpty(sections, 'DOC_TYPE').toLowerCase();
      final aliases = _splitList(_sectionOrEmpty(sections, 'ALIASES'));
      final keywords = _splitList(_sectionOrEmpty(sections, 'KEYWORDS'));
      final summary = _sectionOrEmpty(sections, 'SUMMARY');
      final contentSection = _sectionOrEmpty(sections, 'CONTENT').isEmpty
          ? doc.rawContent
          : _sectionOrEmpty(sections, 'CONTENT');
      final usage = _sectionOrEmpty(sections, 'USAGE');
      final faq = _sectionOrEmpty(sections, 'FAQ');
      final safetyNote = _sectionOrEmpty(sections, 'SAFETY_NOTE');
      final additionalSections = <String, String>{
        if (sections != null)
          for (final entry in sections.entries)
            if (!_searchMetaSections.contains(entry.key) &&
                entry.key != 'CONTENT' &&
                entry.key != 'USAGE' &&
                entry.key != 'FAQ' &&
                entry.key != 'SAFETY_NOTE' &&
                entry.value.trim().isNotEmpty)
              entry.key.toLowerCase(): entry.value.trim(),
      };

      final fieldFolded = <String, String>{
        'name': _foldForSearch(doc.name),
        'title': _foldForSearch(title),
        'aliases': _foldForSearch(aliases.join(' ')),
        'keywords': _foldForSearch(keywords.join(' ')),
        'summary': _foldForSearch(summary),
        'content': _foldForSearch(contentSection),
        'usage': _foldForSearch(usage),
        'faq': _foldForSearch(faq),
        for (final entry in additionalSections.entries)
          entry.key: _foldForSearch(entry.value),
      };
      final fieldCompact = <String, String>{
        for (final entry in fieldFolded.entries)
          entry.key: _compact(entry.value),
      };
      final fieldWeights = <String, ({int phrase, int compact, int token})>{
        'name': (phrase: 72, compact: 56, token: 10),
        'title': (phrase: 56, compact: 42, token: 8),
        'aliases': (phrase: 44, compact: 30, token: 6),
        'keywords': (phrase: 40, compact: 28, token: 5),
        'summary': (phrase: 30, compact: 20, token: 3),
        'content': (phrase: 18, compact: 12, token: 2),
        'usage': (phrase: 20, compact: 14, token: 2),
        'faq': (phrase: 14, compact: 10, token: 1),
        for (final entry in additionalSections.entries)
          entry.key: _weightsForAdditionalSection(entry.key),
      };

      final scoreByField = <String, int>{
        for (final key in fieldFolded.keys) key: 0,
      };
      var hasPhraseMatch = false;
      var hasIdentityMatch = false;
      final matchedTokens = <String>{};
      final strongFieldTokenMatches = <String>{};

      for (final entry in fieldFolded.entries) {
        final key = entry.key;
        final folded = entry.value;
        if (folded.isEmpty) {
          continue;
        }
        final compact = fieldCompact[key] ?? '';
        final weights = fieldWeights[key]!;

        for (final phrase in phrases) {
          if (phrase.isEmpty) {
            continue;
          }
          if (folded.contains(phrase)) {
            scoreByField[key] = (scoreByField[key] ?? 0) + weights.phrase;
            hasPhraseMatch = true;
          }
        }

        for (final compactPhrase in compactPhrases) {
          if (compactPhrase.isEmpty || compact.isEmpty) {
            continue;
          }
          if (compact.contains(compactPhrase)) {
            scoreByField[key] = (scoreByField[key] ?? 0) + weights.compact;
            hasPhraseMatch = true;
          }
        }

        for (final token in tokens) {
          if (token.length < 2) {
            continue;
          }
          final compactToken = _compact(token);
          if (folded.contains(token) ||
              (compactToken.isNotEmpty && compact.contains(compactToken))) {
            scoreByField[key] = (scoreByField[key] ?? 0) + weights.token;
            matchedTokens.add(token);
            if (key == 'name' ||
                key == 'title' ||
                key == 'aliases' ||
                key == 'keywords') {
              strongFieldTokenMatches.add(token);
            }
          }
        }
      }

      final compactTitle = fieldCompact['title'] ?? '';
      final compactAliases = fieldCompact['aliases'] ?? '';
      final compactName = fieldCompact['name'] ?? '';
      if (compactTitle == intent.compactQuery ||
          compactAliases.contains(intent.compactQuery) ||
          compactName == intent.compactQuery) {
        hasIdentityMatch = true;
      }

      var totalScore = scoreByField.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      if (hasIdentityMatch) {
        totalScore += 64;
      }
      if (strongFieldTokenMatches.length >= 2) {
        totalScore += strongFieldTokenMatches.length * 8;
      }

      final coverageRatio = tokens.isEmpty
          ? 0.0
          : matchedTokens.length / tokens.length;
      if (coverageRatio >= 1) {
        totalScore += 26;
      } else if (coverageRatio >= 0.85) {
        totalScore += 20;
      } else if (coverageRatio >= 0.65) {
        totalScore += 12;
      } else if (coverageRatio >= 0.45) {
        totalScore += 6;
      }

      final docTypeBoost = _docTypeBoostForIntent(
        docType: docType,
        intent: intent,
      );
      totalScore += docTypeBoost;
      if (structured) {
        totalScore += 4;
      }

      final hasEnoughTokenEvidence =
          matchedTokens.length >= 2 && coverageRatio >= 0.4;
      if (!hasPhraseMatch && !hasEnoughTokenEvidence && !hasIdentityMatch) {
        continue;
      }
      if (totalScore < 12) {
        continue;
      }

      final sortedFields =
          scoreByField.entries.where((entry) => entry.value > 0).toList()
            ..sort((a, b) => b.value.compareTo(a.value));
      final fieldHits = sortedFields.map((entry) => entry.key).toList();
      final primaryField = fieldHits.isEmpty ? 'content' : fieldHits.first;
      final matchReasons = <String>[];
      if (hasIdentityMatch) {
        matchReasons.add('exact_identity');
      }
      if (docTypeBoost > 0) {
        matchReasons.add('intent_doc_type');
      }
      if (coverageRatio >= 0.85) {
        matchReasons.add('high_token_coverage');
      } else if (coverageRatio >= 0.45) {
        matchReasons.add('partial_token_coverage');
      }
      if (structured) {
        matchReasons.add('structured_kdoc');
      }
      final snippet = switch (primaryField) {
        'name' => title,
        'title' => title,
        'aliases' => 'Tên gọi khác: ${aliases.join(', ')}',
        'keywords' => 'Từ khóa: ${keywords.join(', ')}',
        'summary' => summary,
        'usage' => usage,
        'faq' => faq,
        _ when additionalSections.containsKey(primaryField) =>
          '${_additionalSectionLabel(primaryField)}: ${_snippetFrom(additionalSections[primaryField] ?? '', query)}',
        _ => _snippetFrom(contentSection, query),
      };

      matches.add((
        score: totalScore,
        coverageRatio: coverageRatio,
        matchedTokens: matchedTokens.length,
        exactMatch: hasIdentityMatch,
        doc: doc,
        snippet: snippet.trim(),
        fieldHits: fieldHits,
        matchReasons: matchReasons,
        title: title,
        docType: docType,
        summary: summary,
        usage: usage,
        safetyNote: safetyNote,
        structured: structured,
      ));
    }

    matches.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) {
        return byScore;
      }
      final byCoverage = b.coverageRatio.compareTo(a.coverageRatio);
      if (byCoverage != 0) {
        return byCoverage;
      }
      if (a.exactMatch != b.exactMatch) {
        return b.exactMatch ? 1 : -1;
      }
      return a.doc.name.compareTo(b.doc.name);
    });

    return matches
        .take(topK)
        .map(
          (item) => <String, dynamic>{
            'name': item.doc.name,
            'title': item.title,
            'doc_type': item.docType,
            'score': item.score,
            'coverage_ratio': item.coverageRatio,
            'matched_tokens': item.matchedTokens,
            'query_tokens': tokens.length,
            'exact_match': item.exactMatch,
            'confidence': _confidenceFromScore(
              score: item.score,
              coverageRatio: item.coverageRatio,
              exactMatch: item.exactMatch,
            ),
            'snippet': item.snippet,
            'field_hits': item.fieldHits,
            'match_reasons': item.matchReasons,
            'summary': item.summary,
            'usage': item.usage,
            'safety_note': item.safetyNote,
            'content': item.doc.rawContent,
            'characters': item.doc.rawContent.length,
            'updated_at': item.doc.updatedAt.toIso8601String(),
            'structured': item.structured,
          },
        )
        .toList();
  }

  Future<void> _ensureInitialized() async {
    if (_initFuture != null) {
      await _initFuture;
      return;
    }
    _initFuture = _loadFromDisk();
    await _initFuture;
  }

  Future<File> _resolveStorageFile() async {
    if (_storageFile != null) {
      return _storageFile!;
    }
    final baseDir =
        await (_documentsDirectoryResolver?.call() ??
            getApplicationDocumentsDirectory());
    final storageDir = Directory('${baseDir.path}/voicebot');
    if (!await storageDir.exists()) {
      await storageDir.create(recursive: true);
    }
    _storageFile = File('${storageDir.path}/$_storageFileName');
    return _storageFile!;
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _resolveStorageFile();
      if (!await file.exists()) {
        return;
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final documents = decoded['documents'];
      if (documents is! List) {
        return;
      }

      _documents.clear();
      for (final item in documents) {
        if (item is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(item);
        final name = (map['name'] ?? '').toString().trim();
        final content = (map['content'] ?? '').toString().trim();
        final updatedAtRaw = (map['updated_at'] ?? '').toString().trim();
        if (name.isEmpty || content.isEmpty) {
          continue;
        }
        final updatedAt = DateTime.tryParse(updatedAtRaw) ?? DateTime.now();
        _documents[name] = _KnowledgeDocument(
          name: name,
          rawContent: content,
          foldedContent: _foldForSearch(content),
          compactContent: _compact(_foldForSearch(content)),
          updatedAt: updatedAt,
        );
      }
    } catch (_) {
      // Ignore malformed local storage and continue with empty KB.
    }
  }

  Future<void> _persist() async {
    final file = await _resolveStorageFile();
    final payload = <String, dynamic>{
      'version': _storageVersion,
      'saved_at': DateTime.now().toIso8601String(),
      'documents': _documents.values
          .map(
            (doc) => <String, dynamic>{
              'name': doc.name,
              'content': doc.rawContent,
              'updated_at': doc.updatedAt.toIso8601String(),
            },
          )
          .toList(),
    };
    final contents = jsonEncode(payload);
    if (_storageWriter != null) {
      await _storageWriter!(file, contents);
      return;
    }
    await file.writeAsString(contents, flush: true);
  }

  Map<String, dynamic> _toMeta(_KnowledgeDocument doc) {
    final sections = _parseKdocSections(doc.rawContent);
    final title = (sections?['TITLE'] ?? doc.name).trim();
    final docType = (sections?['DOC_TYPE'] ?? '').trim().toLowerCase();
    final structured =
        sections != null && validateKdocContent(doc.rawContent).isValid;
    return <String, dynamic>{
      'name': doc.name,
      'title': title.isEmpty ? doc.name : title,
      'doc_type': docType.isEmpty ? null : docType,
      'structured': structured,
      'characters': doc.rawContent.length,
      'updated_at': doc.updatedAt.toIso8601String(),
    };
  }

  static Map<String, String>? _parseKdocSections(String content) {
    final normalized = content.replaceAll('\r\n', '\n').trim();
    if (normalized.isEmpty) {
      return null;
    }
    final lines = normalized.split('\n');
    final start = lines.indexWhere((line) => line.trim() == _kdocHeader);
    final end = lines.lastIndexWhere((line) => line.trim() == _kdocFooter);
    if (start < 0 || end <= start) {
      return null;
    }

    final sections = <String, String>{};
    String? currentKey;
    final buffer = <String>[];
    final sectionPattern = RegExp(r'^\s*\[([A-Z_]+)\]\s*$');

    void flush() {
      if (currentKey == null) {
        return;
      }
      final key = currentKey;
      sections[key] = buffer.join('\n').trim();
      buffer.clear();
    }

    for (var i = start + 1; i < end; i++) {
      final line = lines[i];
      final match = sectionPattern.firstMatch(line);
      if (match != null) {
        flush();
        currentKey = match.group(1);
        continue;
      }
      if (currentKey != null) {
        buffer.add(line);
      }
    }
    flush();
    return sections;
  }

  static List<String> _splitList(String raw) {
    return raw
        .split(RegExp(r'[\n|,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
  }

  static String _sectionOrEmpty(Map<String, String>? sections, String key) {
    return (sections?[key] ?? '').trim();
  }

  static String _snippetFrom(String source, String query) {
    final maxLen = 280;
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final foldedQuery = _foldForSearch(query);
    final phrases = _expandSearchPhrases(foldedQuery);
    final compactPhrases = phrases.map(_compact).toSet();
    final tokens = <String>{for (final phrase in phrases) ..._tokenize(phrase)};
    if (tokens.isEmpty) {
      if (trimmed.length <= maxLen) {
        return trimmed;
      }
      return '${trimmed.substring(0, maxLen)}...';
    }

    final lines = source.split('\n');
    var bestLineIndex = -1;
    var bestScore = 0;
    for (var i = 0; i < lines.length; i++) {
      final foldedLine = _foldForSearch(lines[i]);
      if (foldedLine.isEmpty) {
        continue;
      }
      var lineScore = 0;
      for (final phrase in phrases) {
        if (phrase.isEmpty) {
          continue;
        }
        if (foldedLine.contains(phrase)) {
          lineScore += 20;
        }
      }
      final compactLine = _compact(foldedLine);
      for (final compactPhrase in compactPhrases) {
        if (compactPhrase.isEmpty) {
          continue;
        }
        if (compactLine.contains(compactPhrase)) {
          lineScore += 12;
        }
      }
      for (final token in tokens) {
        if (foldedLine.contains(token)) {
          lineScore += 2;
        }
      }
      if (lineScore > bestScore) {
        bestScore = lineScore;
        bestLineIndex = i;
      }
    }

    if (bestLineIndex >= 0 && bestScore > 0) {
      final startLine = (bestLineIndex - 2).clamp(0, lines.length - 1);
      final endLine = (bestLineIndex + 2).clamp(0, lines.length - 1);
      final block = lines.sublist(startLine, endLine + 1).join('\n').trim();
      if (block.length <= maxLen) {
        return block;
      }
      return '${block.substring(0, maxLen)}...';
    }

    if (trimmed.length <= maxLen) {
      return trimmed;
    }
    return '${trimmed.substring(0, maxLen)}...';
  }

  static String _foldForSearch(String input) {
    final aliasNormalized = _normalizeAliases(input);
    return aliasNormalized
        .toLowerCase()
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ầ', 'a')
        .replaceAll('ấ', 'a')
        .replaceAll('ậ', 'a')
        .replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('ằ', 'a')
        .replaceAll('ắ', 'a')
        .replaceAll('ặ', 'a')
        .replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ề', 'e')
        .replaceAll('ế', 'e')
        .replaceAll('ệ', 'e')
        .replaceAll('ể', 'e')
        .replaceAll('ễ', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ồ', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ờ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ử', 'u')
        .replaceAll('ữ', 'u')
        .replaceAll('ỳ', 'y')
        .replaceAll('ý', 'y')
        .replaceAll('ỵ', 'y')
        .replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y')
        .replaceAll('đ', 'd')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _compact(String input) {
    return input.replaceAll(RegExp(r'\s+'), '');
  }

  static Set<String> _tokenize(String input) {
    return input
        .split(RegExp(r'\s+'))
        .where(
          (token) => token.length >= 2 && !_searchStopwords.contains(token),
        )
        .toSet();
  }

  static Set<String> _expandSearchPhrases(String foldedQuery) {
    final base = foldedQuery.trim();
    if (base.isEmpty) {
      return <String>{};
    }

    final phrases = <String>{base};
    final replacements = <RegExp, String>{
      RegExp(r'\bcha\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchai\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchabi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchami\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchamy\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bcha\s*mi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bbo\s*tranh\b', caseSensitive: false): 'bot chanh',
      RegExp(r'\bbot\s*tranh\b', caseSensitive: false): 'bot chanh',
      RegExp(r'\bbo\s*chanh\b', caseSensitive: false): 'bot chanh',
      RegExp(r'\bchanh\s*viet\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\btranh\s*viet\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\bcuoc\s*tranh\b', caseSensitive: false): 'cot chanh',
      RegExp(r'\bcuoc\s*chanh\b', caseSensitive: false): 'cot chanh',
      RegExp(r'\bcot\s*tranh\b', caseSensitive: false): 'cot chanh',
      RegExp(r'\bmuoi\s*ot\s*xanh\b', caseSensitive: false): 'muoi ot xanh',
    };

    var normalized = base;
    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }
    phrases.add(normalized);

    if (normalized.contains('chavi')) {
      phrases.add(normalized.replaceAll('chavi', 'cha vi'));
      phrases.add(normalized.replaceAll('chavi', 'chai vi'));
      phrases.add(normalized.replaceAll('chavi', 'chami'));
    }
    if (normalized.contains('chanhviet')) {
      phrases.add(normalized.replaceAll('chanhviet', 'chanh viet'));
      phrases.add(normalized.replaceAll('chanhviet', 'tranh viet'));
    }

    return phrases.where((item) => item.trim().isNotEmpty).toSet();
  }

  static ({
    Set<String> preferredDocTypes,
    Set<String> focusTerms,
    String compactQuery,
  })
  _analyzeSearchIntent({
    required String foldedQuery,
    required Set<String> tokens,
  }) {
    final preferredDocTypes = <String>{};
    final focusTerms = <String>{};
    final normalized = ' ${foldedQuery.trim()} ';

    void addIfMatches({
      required Set<String> docTypes,
      required List<String> phrases,
      required Set<String> tokenHints,
    }) {
      final phraseMatched = phrases.any(
        (phrase) => phrase.isNotEmpty && normalized.contains(' $phrase '),
      );
      final matchedTokens = tokenHints.where(tokens.contains).toSet();
      if (!phraseMatched && matchedTokens.isEmpty) {
        return;
      }
      preferredDocTypes.addAll(docTypes);
      for (final phrase in phrases) {
        if (phrase.isNotEmpty && normalized.contains(' $phrase ')) {
          focusTerms.add(phrase);
        }
      }
      focusTerms.addAll(matchedTokens);
    }

    addIfMatches(
      docTypes: <String>{'policy', 'faq'},
      phrases: const <String>[
        'chinh sach',
        'doi tra',
        'thanh toan',
        'van chuyen',
        'giao hang',
        'bao hanh',
      ],
      tokenHints: const <String>{'chinh', 'sach', 'doi', 'tra', 'bao', 'hanh'},
    );
    addIfMatches(
      docTypes: <String>{'company_profile', 'info'},
      phrases: const <String>[
        'gioi thieu',
        'doanh nghiep',
        'cong ty',
        'ho so',
        'nha may',
        'vung trong',
        'thi truong',
        'kenh phan phoi',
        'phan phoi',
      ],
      tokenHints: const <String>{
        'gioi',
        'thieu',
        'doanh',
        'nghiep',
        'ty',
        'profile',
        'thi',
        'truong',
        'kenh',
        'phan',
        'phoi',
      },
    );
    addIfMatches(
      docTypes: <String>{'faq', 'info'},
      phrases: const <String>['hoi dap', 'cau hoi thuong gap', 'faq'],
      tokenHints: const <String>{'faq', 'hoi', 'dap'},
    );
    addIfMatches(
      docTypes: <String>{'product', 'info'},
      phrases: const <String>[
        'san pham',
        'thanh phan',
        'xuat xu',
        'han su dung',
        'bao quan',
        'cong dung',
        'uu diem',
        'quy cach',
        'gia',
        'huong dan',
        'cach dung',
      ],
      tokenHints: const <String>{
        'san',
        'pham',
        'thanh',
        'phan',
        'xuat',
        'xu',
        'han',
        'su',
        'dung',
        'bao',
        'quan',
        'gia',
      },
    );
    if (tokens.contains('chavi') ||
        tokens.contains('bot') ||
        tokens.contains('chanh') ||
        tokens.contains('tinh') ||
        tokens.contains('dau') ||
        tokens.contains('syrup')) {
      preferredDocTypes.add('product');
    }

    return (
      preferredDocTypes: preferredDocTypes,
      focusTerms: focusTerms,
      compactQuery: _compact(foldedQuery),
    );
  }

  static int _docTypeBoostForIntent({
    required String docType,
    required ({
      Set<String> preferredDocTypes,
      Set<String> focusTerms,
      String compactQuery,
    })
    intent,
  }) {
    if (docType.isEmpty || intent.preferredDocTypes.isEmpty) {
      return 0;
    }
    final docTypes = intent.preferredDocTypes.toList(growable: false);
    final index = docTypes.indexOf(docType);
    if (index == 0) {
      return 26;
    }
    if (index > 0) {
      return 14;
    }
    return 0;
  }

  static ({int phrase, int compact, int token}) _weightsForAdditionalSection(
    String key,
  ) {
    return switch (key.toUpperCase()) {
      'MARKET' => (phrase: 36, compact: 26, token: 5),
      'SERVICES' => (phrase: 28, compact: 20, token: 4),
      'REGULATIONS' => (phrase: 24, compact: 18, token: 3),
      'RAW_MATERIALS' => (phrase: 24, compact: 18, token: 3),
      'PROCESS' => (phrase: 22, compact: 16, token: 3),
      'FOOD_SAFETY' => (phrase: 22, compact: 16, token: 3),
      _ => (phrase: 18, compact: 12, token: 2),
    };
  }

  static String _additionalSectionLabel(String key) {
    return switch (key.toUpperCase()) {
      'MARKET' => 'Thị trường & kênh phân phối',
      'SERVICES' => 'Dịch vụ',
      'REGULATIONS' => 'Quy định',
      'RAW_MATERIALS' => 'Nguyên liệu',
      'PROCESS' => 'Quy trình',
      'FOOD_SAFETY' => 'An toàn thực phẩm',
      _ => key.toUpperCase(),
    };
  }

  static String _confidenceFromScore({
    required int score,
    required double coverageRatio,
    required bool exactMatch,
  }) {
    if (exactMatch || (score >= 120 && coverageRatio >= 0.65)) {
      return 'high';
    }
    if (score >= 54 && coverageRatio >= 0.4) {
      return 'medium';
    }
    return 'low';
  }

  static String _normalizeAliases(String input) {
    var output = input;
    final replacements = <RegExp, String>{
      RegExp(r'\bcha\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchai\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchabi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchami\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchamy\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bcha-vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bcha\s*mi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchami\s*garden\b', caseSensitive: false): 'chavi garden',
      RegExp(r'\bchamy\s*garden\b', caseSensitive: false): 'chavi garden',
      RegExp(r'\bcha\s*mi\s*garden\b', caseSensitive: false): 'chavi garden',
      RegExp(r'\bbo\s*tranh\b', caseSensitive: false): 'bột chanh',
      RegExp(r'\bbot\s*tranh\b', caseSensitive: false): 'bột chanh',
      RegExp(r'\bbo\s*chanh\b', caseSensitive: false): 'bột chanh',
      RegExp(r'\bchanh\s*viet\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\bchanh\s*việt\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\btranh\s*viet\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\btranh\s*việt\b', caseSensitive: false): 'chanhviet',
      RegExp(r'\bcuộc\s*tranh\b', caseSensitive: false): 'cốt chanh',
      RegExp(r'\bcuoc\s*tranh\b', caseSensitive: false): 'cốt chanh',
      RegExp(r'\bcuộc\s*chanh\b', caseSensitive: false): 'cốt chanh',
      RegExp(r'\bcuoc\s*chanh\b', caseSensitive: false): 'cốt chanh',
      RegExp(r'\bcốt\s*tranh\b', caseSensitive: false): 'cốt chanh',
      RegExp(r'\bcot\s*tranh\b', caseSensitive: false): 'cốt chanh',
    };
    for (final entry in replacements.entries) {
      output = output.replaceAll(entry.key, entry.value);
    }
    return output;
  }
}

class _KnowledgeDocument {
  const _KnowledgeDocument({
    required this.name,
    required this.rawContent,
    required this.foldedContent,
    required this.compactContent,
    required this.updatedAt,
  });

  final String name;
  final String rawContent;
  final String foldedContent;
  final String compactContent;
  final DateTime updatedAt;
}

enum McpPropertyType { boolean, integer, string }

class McpProperty {
  const McpProperty(
    this.name,
    this.type, {
    this.defaultValue,
    this.minValue,
    this.maxValue,
  });

  const McpProperty.boolean(this.name, {bool? defaultBool})
    : type = McpPropertyType.boolean,
      defaultValue = defaultBool,
      minValue = null,
      maxValue = null;

  const McpProperty.integer(this.name, {int? defaultInt, int? min, int? max})
    : type = McpPropertyType.integer,
      defaultValue = defaultInt,
      minValue = min,
      maxValue = max;

  const McpProperty.string(this.name, {String? defaultString})
    : type = McpPropertyType.string,
      defaultValue = defaultString,
      minValue = null,
      maxValue = null;

  final String name;
  final McpPropertyType type;
  final Object? defaultValue;
  final int? minValue;
  final int? maxValue;

  bool get hasDefault => defaultValue != null;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    switch (type) {
      case McpPropertyType.boolean:
        json['type'] = 'boolean';
        break;
      case McpPropertyType.integer:
        json['type'] = 'integer';
        if (minValue != null) {
          json['minimum'] = minValue;
        }
        if (maxValue != null) {
          json['maximum'] = maxValue;
        }
        break;
      case McpPropertyType.string:
        json['type'] = 'string';
        break;
    }
    if (defaultValue != null) {
      json['default'] = defaultValue;
    }
    return json;
  }
}

abstract class McpDeviceController {
  Future<Map<String, dynamic>> getDeviceStatus();
  Future<bool> setSpeakerVolume(int percent);
  Future<Map<String, dynamic>> getSystemInfo();
}

class FlutterMcpDeviceController implements McpDeviceController {
  FlutterMcpDeviceController() {
    if (Platform.isAndroid) {
      unawaited(_ensureAndroidStream());
    }
  }

  static const Duration _statusGraceWindow = Duration(milliseconds: 1200);
  static const Duration _readRetryDelay = Duration(milliseconds: 90);
  static const int _readRetryCount = 4;
  static const int _acceptDiffPercent = 2;

  int? _lastRequestedVolumePercent;
  DateTime? _lastRequestedVolumeAt;

  Future<void> _ensureAndroidStream() async {
    if (!Platform.isAndroid) {
      return;
    }
    await FlutterVolumeController.setAndroidAudioStream(
      stream: AudioStream.music,
    );
  }

  Future<int?> _readVolumePercent() async {
    final volume = await FlutterVolumeController.getVolume(
      stream: AudioStream.music,
    );
    if (volume == null) {
      return null;
    }
    return (volume * 100).round().clamp(0, 100);
  }

  @override
  Future<Map<String, dynamic>> getDeviceStatus() async {
    await _ensureAndroidStream();
    var percent = await _readVolumePercent();
    final requested = _lastRequestedVolumePercent;
    final requestedAt = _lastRequestedVolumeAt;
    if (requested != null && requestedAt != null) {
      final age = DateTime.now().difference(requestedAt);
      final drift = percent == null ? 999 : (percent - requested).abs();
      if (age <= _statusGraceWindow && drift > _acceptDiffPercent) {
        percent = requested;
      }
    }
    return <String, dynamic>{
      'audio_speaker': <String, dynamic>{'volume': percent},
      'platform': Platform.operatingSystem,
    };
  }

  @override
  Future<bool> setSpeakerVolume(int percent) async {
    final clamped = percent.clamp(0, 100);
    final value = clamped / 100.0;
    _lastRequestedVolumePercent = clamped;
    _lastRequestedVolumeAt = DateTime.now();
    try {
      await _ensureAndroidStream();
      await FlutterVolumeController.setVolume(value, stream: AudioStream.music);
      for (var i = 0; i < _readRetryCount; i++) {
        await Future<void>.delayed(_readRetryDelay);
        final current = await _readVolumePercent();
        if (current != null &&
            (current - clamped).abs() <= _acceptDiffPercent) {
          return true;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> getSystemInfo() async {
    return <String, dynamic>{
      'os': Platform.operatingSystem,
      'os_version': Platform.operatingSystemVersion,
    };
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}
