import '../../domain/repositories/chat_repository.dart';

class ObserveChatOutgoingLevelUseCase {
  const ObserveChatOutgoingLevelUseCase(this._repository);

  final ChatRepository _repository;

  Stream<double> call() => _repository.outgoingLevel;
}
