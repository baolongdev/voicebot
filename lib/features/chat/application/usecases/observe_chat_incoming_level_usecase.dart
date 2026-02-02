import '../../domain/repositories/chat_repository.dart';

class ObserveChatIncomingLevelUseCase {
  const ObserveChatIncomingLevelUseCase(this._repository);

  final ChatRepository _repository;

  Stream<double> call() => _repository.incomingLevel;
}
