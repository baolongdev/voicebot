import '../../domain/repositories/chat_repository.dart';

class DisconnectChatUseCase {
  const DisconnectChatUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call() => _repository.disconnect();
}
