class AppLogger {
  static void log(
    String tag,
    String message, {
    String level = 'I',
  }) {
    final timestamp = _timestamp();
    final paddedTag = tag.padRight(24);
    // ignore: avoid_print
    print('$timestamp $paddedTag $level  $message');
  }

  static String _timestamp() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
