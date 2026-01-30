import 'audio_input.dart';
import 'audio_output.dart';
import 'audio_input_recorder.dart';
import 'audio_output_player.dart';

class VoicePlatformFactory {
  const VoicePlatformFactory._();

  static AudioInput createAudioInput() => RecorderAudioInput();

  static AudioOutput createAudioOutput() => PlayerAudioOutput();
}
