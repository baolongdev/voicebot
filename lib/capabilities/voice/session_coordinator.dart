import 'dart:typed_data';

import 'transport_client.dart';

abstract class SessionCoordinator {
  Stream<Map<String, dynamic>> get incomingJson;
  Stream<Uint8List> get incomingAudio;
  Stream<double> get incomingLevel;
  Stream<double> get outgoingLevel;
  Stream<String> get errors;
  Stream<bool> get speaking;
  int get serverSampleRate;

  Future<bool> connect(TransportClient transport);
  Future<void> disconnect();
  Future<void> startListening();
  Future<void> stopListening();
  Future<void> sendText(String text);
  Future<void> sendAudio(List<int> data);
}
