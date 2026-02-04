import '../../../../capabilities/protocol/protocol.dart';
import '../../domain/repositories/chat_repository.dart';

class SetTextSendModeUseCase {
  const SetTextSendModeUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call(TextSendMode mode) => _repository.setTextSendMode(mode);
}
