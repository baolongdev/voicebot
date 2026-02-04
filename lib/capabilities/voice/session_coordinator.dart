import 'dart:typed_data';

import '../protocol/protocol.dart';
import 'transport_client.dart';

abstract class SessionCoordinator {
  Stream<Map<String, dynamic>> get incomingJson;
  Stream<Uint8List> get incomingAudio;
  Stream<double> get incomingLevel;
  Stream<double> get outgoingLevel;
  Stream<String> get errors;
  Stream<bool> get speaking;
  int get serverSampleRate;
  ListeningMode get listeningMode;

  Future<bool> connect(TransportClient transport);
  Future<void> disconnect();
  Future<void> startListening({bool enableMic = true});
  Future<void> stopListening();
  Future<void> sendText(String text);
  Future<void> sendAudio(List<int> data);
  void setListeningMode(ListeningMode mode);
}
