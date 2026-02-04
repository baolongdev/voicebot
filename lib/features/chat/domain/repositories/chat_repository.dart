import '../../../../core/errors/failure.dart';
import '../../../../core/result/result.dart';
import '../../../../capabilities/protocol/protocol.dart';
import '../entities/chat_config.dart';
import '../entities/chat_response.dart';

abstract class ChatRepository {
  Stream<ChatResponse> get responses;
  Stream<List<int>> get audioStream;
  Stream<double> get incomingLevel;
  Stream<double> get outgoingLevel;
  Stream<Failure> get errors;
  Stream<bool> get speakingStream;
  int get serverSampleRate;

  Future<Result<bool>> connect(ChatConfig config);
  Future<void> disconnect();
  Future<void> startListening({bool enableMic = true});
  Future<void> stopListening();
  Future<void> setListeningMode(ListeningMode mode);
  Future<void> setTextSendMode(TextSendMode mode);
  Future<Result<bool>> sendGreeting(String text);
  Future<Result<bool>> sendMessage(String text);
  Future<void> sendAudio(List<int> data);
}
