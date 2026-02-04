import '../../../../core/result/result.dart';
import '../../domain/repositories/chat_repository.dart';

class SendGreetingMessageUseCase {
  const SendGreetingMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<bool>> call(String text) => _repository.sendGreeting(text);
}
