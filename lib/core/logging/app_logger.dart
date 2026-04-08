import 'structured_logger.dart';
import 'logger.dart' show LogLevel;

class AppLogger {
  static void log(String tag, String message, {String level = 'I'}) {
    final mappedLevel = _mapLevel(level);
    switch (mappedLevel) {
      case LogLevel.debug:
        AppLog.I.debug(message, tag: tag);
      case LogLevel.warn:
        AppLog.I.warning(message, tag: tag);
      case LogLevel.error:
        AppLog.I.error(message, tag: tag);
      case LogLevel.info:
        AppLog.I.info(message, tag: tag);
    }
  }

  static void event(
    String tag,
    String name, {
    Map<String, Object?> fields = const <String, Object?>{},
    String level = 'I',
  }) {
    final convertedFields = fields.map((key, value) => MapEntry(key, value));
    switch (tag.toLowerCase()) {
      case 'protocol':
        AppLog.I.protocol(name, fields: convertedFields);
        break;
      case 'audio':
        AppLog.I.audio(name, fields: convertedFields);
        break;
      case 'network':
        AppLog.I.network(name, fields: convertedFields);
        break;
      case 'permission':
        AppLog.I.permission(name, fields: convertedFields);
        break;
      case 'chat':
        AppLog.I.chat(name, fields: convertedFields);
        break;
      case 'ota':
        AppLog.I.ota(name, fields: convertedFields);
        break;
      default:
        AppLog.I.info(name, tag: tag, fields: convertedFields);
    }
  }

  static LogLevel _mapLevel(String level) {
    switch (level.toUpperCase()) {
      case 'D':
        return LogLevel.debug;
      case 'W':
        return LogLevel.warn;
      case 'E':
        return LogLevel.error;
      case 'I':
        return LogLevel.info;
    }
    return LogLevel.info;
  }
}
