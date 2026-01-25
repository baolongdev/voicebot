import '../../../../core/errors/failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import '../../../../core/system/ota/ota.dart' as core_ota;
import '../../../form/infrastructure/repositories/settings_repository.dart';
import '../../domain/entities/chat_config.dart';
import '../../domain/repositories/chat_config_provider.dart';

class ChatConfigProviderImpl implements ChatConfigProvider {
  ChatConfigProviderImpl({
    required SettingsRepository settings,
    required core_ota.Ota ota,
  })  : _settings = settings,
        _ota = ota;

  final SettingsRepository _settings;
  final core_ota.Ota _ota;

  @override
  Future<Result<ChatConfig>> loadConfig() async {
    final url = _settings.webSocketUrl ?? '';
    final token = _settings.webSocketToken ?? '';
    final deviceInfo = _ota.deviceInfo;

    if (url.isEmpty) {
      _logMessage('connect skipped: missing url');
      return Result.failure(
        const Failure(message: 'Chưa có WebSocket URL'),
      );
    }
    if (token.isEmpty) {
      _logMessage('connect skipped: missing websocket token');
      return Result.failure(
        const Failure(message: 'Chưa có websocket token'),
      );
    }
    if (deviceInfo == null) {
      _logMessage('connect skipped: missing device id');
      return Result.failure(
        const Failure(message: 'Chưa có thông tin thiết bị'),
      );
    }

    return Result.success(
      ChatConfig(
        url: url,
        accessToken: token,
        deviceInfo: deviceInfo,
      ),
    );
  }

  void _logMessage(String message) {
    AppLogger.log('ChatConfig', message);
  }
}
