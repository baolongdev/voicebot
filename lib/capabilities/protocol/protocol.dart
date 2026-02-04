import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

// Ported from Android Kotlin: Protocol.kt
enum AbortReason { wakeWordDetected, none }

// Ported from Android Kotlin: Protocol.kt
enum ListeningMode { alwaysOn, autoStop, manual }
enum TextSendMode { listenDetect, text }

// Ported from Android Kotlin: Protocol.kt
enum AudioState { opened, closed }

// Ported from Android Kotlin: Protocol.kt
abstract class Protocol {
  Protocol()
      : incomingJsonStream = StreamController<Map<String, dynamic>>.broadcast(),
        incomingAudioStream = StreamController<Uint8List>.broadcast(),
        audioChannelStateStream = StreamController<AudioState>.broadcast(),
        networkErrorStream = StreamController<String>.broadcast();

  String sessionId = '';

  final StreamController<Map<String, dynamic>> incomingJsonStream;
  final StreamController<Uint8List> incomingAudioStream;
  final StreamController<AudioState> audioChannelStateStream;
  final StreamController<String> networkErrorStream;

  Future<void> start();
  Future<void> sendAudio(Uint8List data);
  Future<bool> openAudioChannel();
  void closeAudioChannel();
  bool isAudioChannelOpened();
  Future<void> sendText(String text);

  Future<void> sendAbortSpeaking(AbortReason reason) async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'type': 'abort',
    };
    if (reason == AbortReason.wakeWordDetected) {
      payload['reason'] = 'wake_word_detected';
    }
    await sendText(jsonEncode(payload));
  }

  Future<void> sendWakeWordDetected(String wakeWord) async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'type': 'listen',
      'state': 'detect',
      'text': wakeWord,
    };
    await sendText(jsonEncode(payload));
  }

  Future<void> sendStartListening(ListeningMode mode) async {
    final modeValue = switch (mode) {
      ListeningMode.alwaysOn => 'realtime',
      ListeningMode.autoStop => 'auto',
      ListeningMode.manual => 'manual',
    };
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'type': 'listen',
      'state': 'start',
      'mode': modeValue,
    };
    await sendText(jsonEncode(payload));
  }

  Future<void> sendStopListening() async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'type': 'listen',
      'state': 'stop',
    };
    await sendText(jsonEncode(payload));
  }

  Future<void> sendIotDescriptors(String descriptors) async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'type': 'iot',
      'descriptors': jsonDecode(descriptors),
    };
    await sendText(jsonEncode(payload));
  }

  Future<void> sendIotStates(String states) async {
    final payload = <String, dynamic>{
      'session_id': sessionId,
      'type': 'iot',
      'states': jsonDecode(states),
    };
    await sendText(jsonEncode(payload));
  }

  void dispose();
}
