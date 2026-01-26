// Ported from Android Kotlin: Ota.kt
class UpgradeState {
  const UpgradeState({
    required this.progress,
    required this.speed,
  });

  final int progress;
  final int speed;
}
