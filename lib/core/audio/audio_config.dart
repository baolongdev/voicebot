import '../config/default_settings.dart';

class AudioConfig {
  AudioConfig._();

  static AudioDefaultSettings? _settings;

  static void setSettings(AudioDefaultSettings settings) {
    _settings = settings;
  }

  static int get sampleRate => 16000;
  static int get channels => 1;
  static int get frameDurationMs => 60;

  static int get minBufferFrames => _settings?.minBufferFrames ?? 3;
  static int get maxBufferFrames => _settings?.maxBufferFrames ?? 10;

  static bool get enableVad => _settings?.vadEnabled ?? false;
  static int get vadThreshold => _settings?.vadThreshold ?? 500;

  static int get defaultVolume => 100;
}
