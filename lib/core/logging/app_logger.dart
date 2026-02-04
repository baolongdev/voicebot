import 'logger.dart';

class AppLogger {
  static void log(
    String tag,
    String message, {
    String level = 'I',
  }) {
    Logger.log(tag, message, level: _mapLevel(level));
  }

  static void event(
    String tag,
    String name, {
    Map<String, Object?> fields = const <String, Object?>{},
    String level = 'I',
  }) {
    Logger.event(tag, name, fields: fields, level: _mapLevel(level));
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
      default:
        return LogLevel.info;
    }
  }
}
