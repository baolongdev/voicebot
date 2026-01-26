import '../../domain/repositories/chat_repository.dart';

class ObserveChatSpeakingUseCase {
  ObserveChatSpeakingUseCase(this._repository);

  final ChatRepository _repository;

  Stream<bool> call() => _repository.speakingStream;
}
