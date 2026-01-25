import 'dart:async';

import 'package:voicebot/core/system/ota/ota.dart';
import '../../domain/models/server_form_data.dart';
import '../../domain/repositories/form_result.dart';
import '../../domain/repositories/form_repository.dart';
import 'settings_repository.dart';

// Ported from Android Kotlin: FormRepository.kt
class FormRepositoryImpl implements FormRepository {
  FormRepositoryImpl({
    required Ota ota,
    required SettingsRepository settingsRepository,
  })  : _ota = ota,
        _settingsRepository = settingsRepository,
        _controller = StreamController<FormResult?>.broadcast(),
        _lastResult = null {
    _controller.add(null);
  }

  final Ota _ota;
  final SettingsRepository _settingsRepository;
  final StreamController<FormResult?> _controller;
  FormResult? _lastResult;

  @override
  Stream<FormResult?> get resultStream => _controller.stream;

  @override
  FormResult? get lastResult => _lastResult;

  @override
  Future<void> submitForm(ServerFormData formData) async {
    if (formData.serverType == ServerType.xiaoZhi) {
      _settingsRepository.transportType = formData.xiaoZhiConfig.transportType;
      _settingsRepository.webSocketUrl = formData.xiaoZhiConfig.webSocketUrl;
      await _ota.checkVersion(formData.xiaoZhiConfig.qtaUrl);
      _lastResult = XiaoZhiResult(_ota.otaResult);
      _controller.add(_lastResult);
      _settingsRepository.mqttConfig = _ota.otaResult?.mqttConfig;
      if (_ota.otaResult?.websocket?.url?.isNotEmpty ?? false) {
        _settingsRepository.webSocketUrl = _ota.otaResult?.websocket?.url;
      }
      _settingsRepository.webSocketToken = _ota.otaResult?.websocket?.token;
    } else {
      _settingsRepository.transportType = formData.selfHostConfig.transportType;
      _settingsRepository.webSocketUrl = formData.selfHostConfig.webSocketUrl;
      _lastResult = const SelfHostResult();
      _controller.add(_lastResult);
      // TODO
    }
    // Print device info for parity with Android implementation.
    // ignore: avoid_print
    print(_ota.deviceInfo);
  }
}
