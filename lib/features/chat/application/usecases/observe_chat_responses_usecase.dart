import '../../domain/entities/chat_response.dart';
import '../../domain/repositories/chat_repository.dart';

class ObserveChatResponsesUseCase {
  const ObserveChatResponsesUseCase(this._repository);

  final ChatRepository _repository;

  Stream<ChatResponse> call() => _repository.responses;
}
