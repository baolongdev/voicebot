import '../../../../core/errors/failure.dart';
import '../../domain/repositories/chat_repository.dart';

class ObserveChatErrorsUseCase {
  const ObserveChatErrorsUseCase(this._repository);

  final ChatRepository _repository;

  Stream<Failure> call() => _repository.errors;
}
