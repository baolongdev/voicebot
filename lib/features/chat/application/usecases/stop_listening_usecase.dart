import '../../domain/repositories/chat_repository.dart';

class StopListeningUseCase {
  StopListeningUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call() => _repository.stopListening();
}
