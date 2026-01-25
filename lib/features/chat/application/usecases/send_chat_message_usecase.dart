import '../../../../core/result/result.dart';
import '../../domain/repositories/chat_repository.dart';

class SendChatMessageUseCase {
  const SendChatMessageUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<bool>> call(String text) => _repository.sendMessage(text);
}
