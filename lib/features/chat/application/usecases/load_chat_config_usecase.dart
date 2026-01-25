import '../../../../core/result/result.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/repositories/chat_config_provider.dart';

class LoadChatConfigUseCase {
  const LoadChatConfigUseCase(this._provider);

  final ChatConfigProvider _provider;

  Future<Result<ChatConfig>> call() => _provider.loadConfig();
}
