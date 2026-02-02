import '../../../../core/errors/failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/result/result.dart';
import '../../../../core/system/ota/ota.dart' as core_ota;
import '../../../form/domain/models/server_form_data.dart';
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

  static const String _missingUrlCode = 'missing_url';
  static const String _missingTokenCode = 'missing_token';
  static const String _missingDeviceCode = 'missing_device';
  static const String _missingMqttCode = 'missing_mqtt';

  @override
  Future<Result<ChatConfig>> loadConfig() async {
    try {
      await _settings.hydrate().timeout(const Duration(seconds: 2));
    } catch (_) {
      _logMessage('hydrate timeout, using cached settings');
    }
    _settings.normalizeTransport();
    final url = _settings.webSocketUrl ?? '';
    final token = _settings.webSocketToken ?? '';
    final deviceInfo = _ota.deviceInfo;
    final transportType = _settings.transportType;
    final mqttConfig = _settings.mqttConfig;

    if (deviceInfo == null) {
      _logMessage('connect skipped: missing device id');
      return Result.failure(
        const Failure(message: 'Chưa có thông tin thiết bị', code: _missingDeviceCode),
      );
    }
    if (transportType == TransportType.mqtt && mqttConfig == null) {
      _logMessage('connect skipped: missing mqtt config');
      return Result.failure(
        const Failure(message: 'Chưa có cấu hình MQTT', code: _missingMqttCode),
      );
    }
    if (transportType == TransportType.webSockets) {
      if (url.isEmpty) {
        _logMessage('connect skipped: missing url');
        return Result.failure(
          const Failure(message: 'Chưa có WebSocket URL', code: _missingUrlCode),
        );
      }
      if (token.isEmpty) {
        _logMessage('connect skipped: missing websocket token');
        return Result.failure(
          const Failure(
            message: 'Chưa có websocket token',
            code: _missingTokenCode,
          ),
        );
      }
    }

    return Result.success(
      ChatConfig(
        url: url,
        accessToken: token,
        deviceInfo: deviceInfo,
        transportType: transportType,
        mqttConfig: mqttConfig,
      ),
    );
  }

  void _logMessage(String message) {
    AppLogger.log('ChatConfig', message);
  }
}
