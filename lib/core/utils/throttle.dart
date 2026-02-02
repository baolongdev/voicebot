class Throttler {
  Throttler(this.intervalMs);

  final int intervalMs;
  int _lastTick = 0;

  bool shouldRun() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTick < intervalMs) {
      return false;
    }
    _lastTick = now;
    return true;
  }
}
