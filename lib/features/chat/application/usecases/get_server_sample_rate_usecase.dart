import '../../domain/repositories/chat_repository.dart';

class GetServerSampleRateUseCase {
  const GetServerSampleRateUseCase(this._repository);

  final ChatRepository _repository;

  int call() => _repository.serverSampleRate;
}
