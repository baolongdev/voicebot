import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_volume_controller/flutter_volume_controller.dart';

class McpServer {
  McpServer({McpDeviceController? controller})
      : _controller = controller ?? FlutterMcpDeviceController() {
    _registerTools();
  }

  final McpDeviceController _controller;
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
        return _replyResult(
          id,
          <String, dynamic>{
            'protocolVersion': '2024-11-05',
            'capabilities': <String, dynamic>{'tools': <String, dynamic>{}},
            'serverInfo': <String, dynamic>{
              'name': 'voicebot_flutter',
              'version': '1.0.0',
            },
          },
        );
      case 'tools/list':
        final cursor =
            params != null ? params['cursor'] as String? ?? '' : '';
        final withUserTools =
            params != null ? params['withUserTools'] as bool? ?? false : false;
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
        return _handleToolCall(
          id,
          name,
          arguments as Map<String, dynamic>?,
        );
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
    return <String, dynamic>{
      'jsonrpc': '2.0',
      'id': id,
      'result': result,
    };
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
            'Provides the real-time information of the device, including the '
            'current status of the audio speaker, screen, battery, network, '
            'etc. Use this tool to answer questions about current condition.',
        properties: const <McpProperty>[],
        callback: (_) => _controller.getDeviceStatus(),
      ),
    );

    addTool(
      McpTool(
        name: 'self.audio_speaker.set_volume',
        description:
            'Set the volume of the audio speaker. If the current volume is '
            'unknown, you must call `self.get_device_status` tool first and '
            'then call this tool.',
        properties: const <McpProperty>[
          McpProperty.integer('volume', min: 0, max: 100),
        ],
        callback: (args) async {
          final volume = args['volume'] as int? ?? 0;
          return _controller.setSpeakerVolume(volume);
        },
      ),
    );

    addUserOnlyTool(
      McpTool(
        name: 'self.get_system_info',
        description: 'Get the system information',
        properties: const <McpProperty>[],
        callback: (_) => _controller.getSystemInfo(),
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

  const McpProperty.integer(
    this.name, {
    int? defaultInt,
    int? min,
    int? max,
  })  : type = McpPropertyType.integer,
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
      unawaited(
        FlutterVolumeController.setAndroidAudioStream(
          stream: AudioStream.music,
        ),
      );
    }
  }

  @override
  Future<Map<String, dynamic>> getDeviceStatus() async {
    final volume = await FlutterVolumeController.getVolume(
      stream: AudioStream.music,
    );
    final percent = volume == null ? null : (volume * 100).round();
    return <String, dynamic>{
      'audio_speaker': <String, dynamic>{'volume': percent},
      'platform': Platform.operatingSystem,
    };
  }

  @override
  Future<bool> setSpeakerVolume(int percent) async {
    final clamped = percent.clamp(0, 100);
    final value = clamped / 100.0;
    try {
      await FlutterVolumeController.setVolume(
        value,
        stream: AudioStream.music,
      );
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
