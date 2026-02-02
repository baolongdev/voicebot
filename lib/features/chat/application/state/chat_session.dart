import 'chat_state.dart';

abstract class ChatSession {
  Stream<ChatState> get stream;
  ChatState get state;
  Future<void> connect();
  Future<void> disconnect({bool userInitiated = true});
}
