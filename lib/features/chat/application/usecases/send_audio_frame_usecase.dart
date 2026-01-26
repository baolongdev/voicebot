import '../../domain/repositories/chat_repository.dart';

class SendAudioFrameUseCase {
  const SendAudioFrameUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call(List<int> data) => _repository.sendAudio(data);
}
