import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:path_provider/path_provider.dart';

class McpServer {
  static final McpServer shared = McpServer();

  McpServer({McpDeviceController? controller})
    : _controller = controller ?? FlutterMcpDeviceController() {
    _registerTools();
  }

  final McpDeviceController _controller;
  final LocalKnowledgeBase _knowledgeBase = LocalKnowledgeBase();
  final List<McpTool> _tools = <McpTool>[];
  List<McpTool> get tools => List<McpTool>.unmodifiable(_tools);

  Future<Map<String, dynamic>?> handleMessage(
    Map<String, dynamic> payload,
  ) async {
    final jsonrpc = payload['jsonrpc'];
    if (jsonrpc != '2.0') {
      return null;
    }
    final method = payload['method'];
    if (method is! String) {
      return null;
    }
    if (method.startsWith('notifications')) {
      return null;
    }
    final id = payload['id'];
    if (id is! num) {
      return null;
    }

    final params = payload['params'];
    if (params != null && params is! Map<String, dynamic>) {
      return _replyError(id, 'Invalid params for method: $method');
    }

    switch (method) {
      case 'initialize':
        return _replyResult(id, <String, dynamic>{
          'protocolVersion': '2024-11-05',
          'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
          'serverInfo': <String, dynamic>{
            'name': 'voicebot_flutter',
            'version': '1.0.0',
          },
        });
      case 'tools/list':
        final cursor = params != null ? params['cursor'] as String? ?? '' : '';
        final withUserTools = params != null
            ? params['withUserTools'] as bool? ?? false
            : false;
        return _replyResult(
          id,
          _buildToolsList(cursor: cursor, withUserTools: withUserTools),
        );
      case 'tools/call':
        if (params is! Map<String, dynamic>) {
          return _replyError(id, 'Missing params');
        }
        final name = params['name'];
        if (name is! String) {
          return _replyError(id, 'Missing name');
        }
        final arguments = params['arguments'];
        if (arguments != null && arguments is! Map<String, dynamic>) {
          return _replyError(id, 'Invalid arguments');
        }
        return _handleToolCall(id, name, arguments as Map<String, dynamic>?);
      default:
        return _replyError(id, 'Method not implemented: $method');
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
    num id,
    String name,
    Map<String, dynamic>? arguments,
  ) async {
    final tool = _tools.where((tool) => tool.name == name).firstOrNull;
    if (tool == null) {
      return _replyError(id, 'Unknown tool: $name');
    }

    Map<String, Object?> bound;
    try {
      bound = _bindArguments(tool, arguments ?? <String, dynamic>{});
    } catch (error) {
      return _replyError(id, error.toString().replaceFirst('Exception: ', ''));
    }

    try {
      final value = await tool.callback(bound);
      return _replyResult(id, _wrapToolResult(value));
    } catch (error) {
      return _replyError(id, error.toString().replaceFirst('Exception: ', ''));
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
              : rawValue is num
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

  Map<String, dynamic> _replyResult(num id, Object result) {
    return <String, dynamic>{'jsonrpc': '2.0', 'id': id, 'result': result};
  }

  Map<String, dynamic> _replyError(num id, String message) {
    return <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'error': <String, dynamic>{'message': message},
    };
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
            'dang ky kenh',
            'dang ky',
            'subcribe',
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
                'Xin loi, minh chua nghe ro noi dung. Ban vui long dat lai cau hoi ngan gon de minh ho tro chinh xac hon.',
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
            '`KDOC v1` (có các block [DOC_ID], [DOC_TYPE], [TITLE], '
            '[ALIASES], [SUMMARY], [CONTENT], [LAST_UPDATED]).\n'
            'Kết quả: JSON gồm trạng thái upload, metadata tài liệu và tổng '
            'số tài liệu.\n'
            '[EN] Purpose: Upload raw text to the knowledge base '
            '(insert/update by document name).\n'
            'Usage: provide `name` (document name) and `text` in `KDOC v1` '
            'schema.\n'
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
            'field sau này.\n'
            'Cách dùng: truyền `path` (bắt buộc), `name` (tuỳ chọn - nếu '
            'bỏ trống sẽ lấy tên file).\n'
            'Kết quả: JSON gồm trạng thái upload, metadata tài liệu và tổng '
            'số tài liệu.\n'
            '[EN] Purpose: Upload a local file into the knowledge base. '
            'Supports KDOC v1 text-like files for structured search.\n'
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
        name: 'self.knowledge.clear',
        description:
            '[VI] Mục đích: Xoá toàn bộ tài liệu trong kho tri thức.\n'
            'Cách dùng: gọi không cần tham số.\n'
            'Kết quả: JSON gồm `cleared=true` và số lượng đã xoá (`removed`).\n'
            '[EN] Purpose: Remove all documents from the knowledge base.\n'
            'Usage: call without arguments.\n'
            'Return: JSON with `cleared=true` and removed count (`removed`).',
        properties: const <McpProperty>[],
        callback: (_) async {
          final removed = await _knowledgeBase.clear();
          return <String, dynamic>{'cleared': true, 'removed': removed};
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
    'guide',
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
  final Map<String, _KnowledgeDocument> _documents =
      <String, _KnowledgeDocument>{};
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
    if (docId.isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9_.-]+$').hasMatch(docId)) {
      errors.add('[DOC_ID] chỉ được chứa chữ, số, `_`, `-`, `.`.');
    }

    return KdocValidationResult(
      isValid: errors.isEmpty,
      errors: List<String>.unmodifiable(errors),
    );
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
    _documents[normalizedName] = doc;
    await _persist();
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

  Future<int> clear() async {
    await _ensureInitialized();
    final removed = _documents.length;
    _documents.clear();
    await _persist();
    return removed;
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

    final matches = <({
      int score,
      _KnowledgeDocument doc,
      String snippet,
      List<String> fieldHits,
      String title,
      String docType,
      String summary,
      String usage,
      String safetyNote,
      bool structured,
    })>[];
    for (final doc in _documents.values) {
      final sections = _parseKdocSections(doc.rawContent);
      final structured = sections != null && validateKdocContent(doc.rawContent).isValid;

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

      final fieldFolded = <String, String>{
        'title': _foldForSearch(title),
        'aliases': _foldForSearch(aliases.join(' ')),
        'keywords': _foldForSearch(keywords.join(' ')),
        'summary': _foldForSearch(summary),
        'content': _foldForSearch(contentSection),
        'usage': _foldForSearch(usage),
        'faq': _foldForSearch(faq),
      };
      final fieldCompact = <String, String>{
        for (final entry in fieldFolded.entries) entry.key: _compact(entry.value),
      };
      final fieldWeights = <String, ({int phrase, int compact, int token})>{
        'title': (phrase: 56, compact: 42, token: 8),
        'aliases': (phrase: 44, compact: 30, token: 6),
        'keywords': (phrase: 40, compact: 28, token: 5),
        'summary': (phrase: 30, compact: 20, token: 3),
        'content': (phrase: 18, compact: 12, token: 2),
        'usage': (phrase: 20, compact: 14, token: 2),
        'faq': (phrase: 14, compact: 10, token: 1),
      };

      final scoreByField = <String, int>{
        for (final key in fieldFolded.keys) key: 0,
      };
      var hasPhraseMatch = false;
      var tokenMatches = 0;

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
            tokenMatches += 1;
          }
        }
      }

      final totalScore = scoreByField.values.fold<int>(
        0,
        (sum, value) => sum + value,
      );
      final hasEnoughTokenEvidence = tokenMatches >= 2;
      if (!hasPhraseMatch && !hasEnoughTokenEvidence) {
        continue;
      }
      if (totalScore < 6) {
        continue;
      }

      final sortedFields = scoreByField.entries
          .where((entry) => entry.value > 0)
          .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final fieldHits = sortedFields.map((entry) => entry.key).toList();
      final primaryField = fieldHits.isEmpty ? 'content' : fieldHits.first;
      final snippet = switch (primaryField) {
        'title' => title,
        'aliases' => 'Tên gọi khác: ${aliases.join(', ')}',
        'keywords' => 'Từ khóa: ${keywords.join(', ')}',
        'summary' => summary,
        'usage' => usage,
        'faq' => faq,
        _ => _snippetFrom(contentSection, query),
      };

      matches.add((
        score: totalScore,
        doc: doc,
        snippet: snippet.trim(),
        fieldHits: fieldHits,
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
            'snippet': item.snippet,
            'field_hits': item.fieldHits,
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
    final baseDir = await getApplicationDocumentsDirectory();
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
    try {
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
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      // Keep in-memory state even if disk write fails.
    }
  }

  Map<String, dynamic> _toMeta(_KnowledgeDocument doc) {
    final sections = _parseKdocSections(doc.rawContent);
    final title = (sections?['TITLE'] ?? doc.name).trim();
    final docType = (sections?['DOC_TYPE'] ?? '').trim().toLowerCase();
    final structured = sections != null && validateKdocContent(doc.rawContent).isValid;
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
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
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
    }
    if (normalized.contains('chanhviet')) {
      phrases.add(normalized.replaceAll('chanhviet', 'chanh viet'));
      phrases.add(normalized.replaceAll('chanhviet', 'tranh viet'));
    }

    return phrases.where((item) => item.trim().isNotEmpty).toSet();
  }

  static String _normalizeAliases(String input) {
    var output = input;
    final replacements = <RegExp, String>{
      RegExp(r'\bcha\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bchai\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\btra\s*vi\b', caseSensitive: false): 'chavi',
      RegExp(r'\bcha-vi\b', caseSensitive: false): 'chavi',
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
