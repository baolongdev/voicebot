import '../../domain/repositories/chat_repository.dart';

class StartListeningUseCase {
  const StartListeningUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call() => _repository.startListening();
}
