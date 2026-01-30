import 'dart:typed_data';

import '../protocol/protocol.dart';

abstract class TransportClient {
  Stream<Map<String, dynamic>> get jsonStream;
  Stream<Uint8List> get audioStream;
  Stream<String> get errorStream;
  int get serverSampleRate;
  String get sessionId;

  Future<bool> connect();
  Future<void> disconnect();
  Future<void> sendText(String text);
  Future<void> sendAudio(Uint8List data);
  Future<void> startListening(ListeningMode mode);
  Future<void> stopListening();
}
