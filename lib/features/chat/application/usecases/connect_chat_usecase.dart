import '../../../../core/result/result.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/repositories/chat_repository.dart';

class ConnectChatUseCase {
  const ConnectChatUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<bool>> call(ChatConfig config) => _repository.connect(config);
}
