import '../../../../capabilities/protocol/protocol.dart';
import '../../domain/repositories/chat_repository.dart';

class SetListeningModeUseCase {
  const SetListeningModeUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call(ListeningMode mode) => _repository.setListeningMode(mode);
}
