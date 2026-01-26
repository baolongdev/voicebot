import '../../../../core/result/result.dart';
import '../entities/chat_config.dart';

abstract class ChatConfigProvider {
  Future<Result<ChatConfig>> loadConfig();
}
