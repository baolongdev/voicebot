import '../../domain/repositories/chat_repository.dart';

class StartListeningUseCase {
  const StartListeningUseCase(this._repository);

  final ChatRepository _repository;

  Future<void> call({bool enableMic = true}) =>
      _repository.startListening(enableMic: enableMic);
}
