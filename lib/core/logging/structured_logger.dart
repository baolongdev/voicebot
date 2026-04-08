import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'logger.dart' show LogLevel;
import '../config/default_settings.dart';

class AppLog {
  AppLog._()
    : _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 90,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.dateAndTime,
        ),
        level: kDebugMode ? null : Level.info,
      );

  final Logger _logger;

  static final AppLog _instance = AppLog._();
  static AppLog get I => _instance;

  LoggingDefaultSettings? _settings;

  void updateSettings(LoggingDefaultSettings settings) {
    _settings = settings;
  }

  bool get _verbose => _settings?.verbose ?? kDebugMode;
  bool get _logAudio => _settings?.logAudio ?? false;
  bool get _logMcp => _settings?.logMcp ?? true;
  bool get _logWebsocket => _settings?.logWebsocket ?? true;
  bool get _logNetwork => _settings?.logNetwork ?? true;

  void debug(String message, {String? tag, Map<String, dynamic>? fields}) {
    if (!_verbose) return;
    _log(LogLevel.debug, message, tag: tag, fields: fields);
  }

  void info(String message, {String? tag, Map<String, dynamic>? fields}) {
    _log(LogLevel.info, message, tag: tag, fields: fields);
  }

  void warning(String message, {String? tag, Map<String, dynamic>? fields}) {
    _log(LogLevel.warn, message, tag: tag, fields: fields);
  }

  void error(
    String message, {
    String? tag,
    Map<String, dynamic>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      message,
      tag: tag,
      fields: fields,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String message, {
    String? tag,
    Map<String, dynamic>? fields,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final buffer = StringBuffer(message);
    if (fields != null && fields.isNotEmpty) {
      buffer.write(' | ');
      fields.forEach((key, value) {
        buffer.write('$key=$value, ');
      });
    }
    final output = buffer.toString().trim();
    final prefix = tag != null ? '[$tag] ' : '';

    switch (level) {
      case LogLevel.debug:
        _logger.d('$prefix$output');
      case LogLevel.info:
        _logger.i('$prefix$output');
      case LogLevel.warn:
        _logger.w('$prefix$output');
      case LogLevel.error:
        if (error != null && stackTrace != null) {
          _logger.e('$prefix$output', error: error, stackTrace: stackTrace);
        } else if (error != null) {
          _logger.e('$prefix$output', error: error);
        } else {
          _logger.e('$prefix$output');
        }
    }
  }

  void protocol(String event, {Map<String, dynamic>? fields}) {
    if (!_logWebsocket) return;
    _log(LogLevel.info, 'PROTOCOL: $event', tag: 'Protocol', fields: fields);
  }

  void audio(String event, {Map<String, dynamic>? fields}) {
    if (!_logAudio) return;
    _log(LogLevel.info, 'AUDIO: $event', tag: 'Audio', fields: fields);
  }

  void mcp(String event, {Map<String, dynamic>? fields}) {
    if (!_logMcp) return;
    _log(LogLevel.info, 'MCP: $event', tag: 'MCP', fields: fields);
  }

  void network(String event, {Map<String, dynamic>? fields}) {
    if (!_logNetwork) return;
    _log(LogLevel.info, 'NETWORK: $event', tag: 'Network', fields: fields);
  }

  void permission(String event, {Map<String, dynamic>? fields}) {
    _log(
      LogLevel.info,
      'PERMISSION: $event',
      tag: 'Permission',
      fields: fields,
    );
  }

  void chat(String event, {Map<String, dynamic>? fields}) {
    _log(LogLevel.info, 'CHAT: $event', tag: 'Chat', fields: fields);
  }

  void ota(String event, {Map<String, dynamic>? fields}) {
    _log(LogLevel.info, 'OTA: $event', tag: 'OTA', fields: fields);
  }
}
