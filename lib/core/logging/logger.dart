import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warn,
  error,
}

class Logger {
  const Logger._();

  static void log(
    String tag,
    String message, {
    LogLevel level = LogLevel.info,
  }) {
    if (kReleaseMode && level == LogLevel.debug) {
      return;
    }
    final timestamp = _timestamp();
    final paddedTag = tag.padRight(24);
    final levelCode = _levelCode(level);
    // ignore: avoid_print
    print('$timestamp $paddedTag $levelCode  $message');
  }

  static void event(
    String tag,
    String name, {
    Map<String, Object?> fields = const <String, Object?>{},
    LogLevel level = LogLevel.info,
  }) {
    final buffer = StringBuffer('event=$name');
    fields.forEach((key, value) {
      if (value == null) {
        return;
      }
      buffer.write(' $key=$value');
    });
    log(tag, buffer.toString(), level: level);
  }

  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  static String _levelCode(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warn:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }
}
