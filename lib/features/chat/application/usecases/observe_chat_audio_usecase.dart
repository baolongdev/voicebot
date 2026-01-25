import '../../domain/repositories/chat_repository.dart';

class ObserveChatAudioUseCase {
  const ObserveChatAudioUseCase(this._repository);

  final ChatRepository _repository;

  Stream<List<int>> call() => _repository.audioStream;
}
