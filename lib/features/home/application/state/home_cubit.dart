import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/system/ota/ota.dart' as core_ota;
import '../../../../core/system/ota/model/ota_result.dart';
import '../../../chat/application/state/chat_state.dart';
import '../../../chat/application/state/chat_session.dart';
import '../../../form/domain/models/server_form_data.dart';
import '../../../form/infrastructure/repositories/settings_repository.dart';
import '../../domain/entities/home_wifi_network.dart';
import '../../domain/services/home_system_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  HomeCubit({
    required SettingsRepository settingsRepository,
    required core_ota.Ota ota,
    required ChatSession chatCubit,
    required HomeSystemService systemService,
  })  : _settingsRepository = settingsRepository,
        _ota = ota,
        _chatCubit = chatCubit,
        _systemService = systemService,
        super(HomeState.initial()) {
    _chatSubscription = _chatCubit.stream.listen(_handleChatStateChanged);
  }

  final SettingsRepository _settingsRepository;
  final core_ota.Ota _ota;
  final ChatSession _chatCubit;
  final HomeSystemService _systemService;

  Timer? _activationPoller;
  Timer? _activationProgressTimer;
  Timer? _clockTimer;
  StreamSubscription<ChatState>? _chatSubscription;
  StreamSubscription? _batteryStateSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<double>? _volumeSub;
  StreamSubscription? _audioDeviceSub;
  bool _connectInFlight = false;
  bool _disposed = false;
  bool _systemInitialized = false;

  static const Duration _activationPollInterval = Duration(seconds: 10);
  static const Duration _activationProgressStep = Duration(milliseconds: 200);
  static const Duration _clockTick = Duration(minutes: 1);

  Future<void> initialize() async {
    if (_systemInitialized) {
      return;
    }
    _systemInitialized = true;
    emit(state.copyWith(now: DateTime.now()));
    _clockTimer = Timer.periodic(_clockTick, (_) {
      if (_disposed || isClosed) {
        return;
      }
      emit(state.copyWith(now: DateTime.now()));
    });

    final batteryLevel = await _systemService.fetchBatteryLevel();
    final connectivity = await _systemService.fetchConnectivity();
    final wifiName = await _systemService.fetchWifiName();
    final carrierName = await _systemService.fetchCarrierName();
    final volume = await _systemService.fetchVolume();
    final audioDevice = await _systemService.fetchAudioDevice();

    emit(
      state.copyWith(
        batteryLevel: batteryLevel,
        connectivity: connectivity,
        wifiName: wifiName,
        carrierName: carrierName,
        volume: volume,
        audioDevice: audioDevice,
      ),
    );

    _batteryStateSub =
        _systemService.batteryStateStream.listen((batteryState) {
      emit(state.copyWith(batteryState: batteryState));
    });
    _connectivitySub =
        _systemService.connectivityStream.listen((results) async {
      emit(state.copyWith(connectivity: results));
      final name = await _systemService.fetchWifiName();
      emit(state.copyWith(wifiName: name));
    });
    _volumeSub = _systemService.volumeStream.listen((value) {
      emit(state.copyWith(volume: value));
    });
    _audioDeviceSub = _systemService.audioDeviceStream.listen((device) {
      emit(state.copyWith(audioDevice: device));
    });
  }

  Future<void> connect() async {
    final chatConnected = _chatCubit.state.isConnected;
    if (_connectInFlight ||
        state.isConnecting ||
        state.awaitingActivation ||
        (state.isConnected && chatConnected)) {
      return;
    }
    _connectInFlight = true;
    emit(
      state.copyWith(
        isConnecting: true,
        errorMessage: null,
      ),
    );

    try {
      final outcome = await _prepareConnection();
      if (!outcome.ready) {
        emit(
          state.copyWith(
            isConnecting: false,
            isConnected: false,
            awaitingActivation: outcome.awaitingActivation,
            activationProgress: 0,
            activation: outcome.activation,
            errorMessage: outcome.errorMessage,
          ),
        );
        if (outcome.awaitingActivation && outcome.qtaUrl != null) {
          _startActivationPolling(outcome.qtaUrl!);
        }
        return;
      }

      try {
        await _chatCubit
            .disconnect(userInitiated: false)
            .timeout(const Duration(seconds: 1));
      } catch (_) {}
      try {
        await _chatCubit
            .connect()
            .timeout(const Duration(seconds: 12));
      } on TimeoutException {
        await _chatCubit.disconnect();
        emit(
          state.copyWith(
            isConnecting: false,
            isConnected: false,
            awaitingActivation: false,
            activationProgress: 0,
            activation: outcome.activation,
            errorMessage: 'Kết nối quá lâu, vui lòng thử lại.',
          ),
        );
        return;
      }
      final error = _chatCubit.state.connectionError;
      emit(
        state.copyWith(
          isConnecting: false,
          isConnected: error == null || error.isEmpty,
          awaitingActivation: false,
          activationProgress: 0,
          activation: outcome.activation,
          errorMessage: error,
        ),
      );
    } finally {
      _connectInFlight = false;
    }
  }

  Future<void> disconnect() async {
    _stopActivationPolling();
    emit(
      state.copyWith(
        isConnecting: false,
        isConnected: false,
        awaitingActivation: false,
        activationProgress: 0,
        errorMessage: null,
      ),
    );
    await _chatCubit.disconnect(userInitiated: true);
  }

  Future<_PrepareOutcome> _prepareConnection() async {
    await _settingsRepository.hydrate();
    _settingsRepository.normalizeTransport();

    final qtaUrl = XiaoZhiConfig().qtaUrl;
    await _ota.checkVersion(qtaUrl);
    final deviceInfo = _ota.deviceInfo;
    final otaResult = _ota.otaResult;
    final activation = otaResult?.activation;
    AppLogger.event(
      'HomeCubit',
      'ota_result',
      fields: {
        'has_activation': activation != null,
        'activation_code': activation?.code,
        'activation_message': activation?.message,
        'has_ws': otaResult?.websocket != null,
        'has_mqtt': otaResult?.mqttConfig != null,
      },
    );
    if (activation != null) {
      return _PrepareOutcome.awaitingActivation(
        activation: activation,
        qtaUrl: qtaUrl,
      );
    }

    if (otaResult != null) {
      _settingsRepository.applyOtaResult(otaResult);
      _settingsRepository.normalizeTransport();
    }

    final ready = _hasReadyConfig(deviceInfo != null);
    if (ready) {
      return _PrepareOutcome.ready(
        activation: null,
      );
    }

    return _PrepareOutcome.error('Chưa có cấu hình XiaoZhi');
  }

  bool _hasReadyConfig(bool hasDevice) {
    if (!hasDevice) {
      return false;
    }
    final hasWs = _settingsRepository.hasValidWebSocketConfig;
    final hasMqtt = _settingsRepository.hasValidMqttConfig;
    if (_settingsRepository.transportType == TransportType.webSockets) {
      return hasWs;
    }
    if (_settingsRepository.transportType == TransportType.mqtt) {
      return hasMqtt;
    }
    return hasWs || hasMqtt;
  }

  void _startActivationPolling(String qtaUrl) {
    if (_activationPoller != null) {
      return;
    }
    _startActivationProgress();
    _activationPoller = Timer.periodic(_activationPollInterval, (_) async {
      await _ota.checkVersion(qtaUrl);
      final activation = _ota.otaResult?.activation;
      AppLogger.event(
        'HomeCubit',
        'activation_poll',
        fields: {
          'has_activation': activation != null,
          'activation_code': activation?.code,
          'activation_message': activation?.message,
        },
      );
      if (activation == null) {
        _stopActivationPolling();
        emit(
          state.copyWith(
            awaitingActivation: false,
            activationProgress: 0,
            activation: null,
          ),
        );
        await connect();
      } else {
        emit(state.copyWith(activation: activation));
      }
    });
  }

  void _stopActivationPolling() {
    _activationPoller?.cancel();
    _activationPoller = null;
    _stopActivationProgress();
  }

  void _startActivationProgress() {
    _activationProgressTimer?.cancel();
    _activationProgressTimer =
        Timer.periodic(_activationProgressStep, (_) {
      if (_disposed || isClosed) {
        return;
      }
      var next = state.activationProgress + 0.02;
      if (next >= 1) {
        next = 0;
      }
      emit(state.copyWith(activationProgress: next));
    });
  }

  void _stopActivationProgress() {
    _activationProgressTimer?.cancel();
    _activationProgressTimer = null;
  }

  Future<void> refreshWifiNetworks() async {
    emit(state.copyWith(wifiLoading: true, wifiError: null));
    try {
      final networks = await _systemService.scanWifiNetworks();
      emit(state.copyWith(wifiNetworks: networks, wifiLoading: false));
    } catch (_) {
      emit(state.copyWith(
        wifiLoading: false,
        wifiError: 'Không thể quét Wi‑Fi, thử lại sau.',
      ));
    }
  }

  Future<bool> connectToWifi(
    HomeWifiNetwork network,
    String password,
  ) async {
    emit(state.copyWith(wifiLoading: true, wifiError: null));
    final success = await _systemService.connectToWifi(network, password);
    if (!success) {
      emit(state.copyWith(
        wifiLoading: false,
        wifiError: 'Kết nối Wi‑Fi thất bại.',
      ));
      return false;
    }
    emit(state.copyWith(wifiLoading: false));
    return true;
  }

  Future<void> openWifiSettings() async {
    await _systemService.openWifiSettings();
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    await _systemService.setVolume(clamped);
    emit(state.copyWith(volume: clamped));
  }

  Future<void> refreshNetworkStatus() async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (_disposed || isClosed) {
        return;
      }
      final connectivity = await _systemService.fetchConnectivity();
      emit(state.copyWith(connectivity: connectivity));
      final name = await _systemService.fetchWifiName();
      emit(state.copyWith(wifiName: name));
      final cleaned = _cleanWifiName(name);
      if (cleaned != null && cleaned.isNotEmpty) {
        emit(state.copyWith(
          connectivity: const <ConnectivityResult>[ConnectivityResult.wifi],
        ));
        return;
      }
    }
  }

  void _handleChatStateChanged(ChatState chatState) {
    final connected = chatState.isConnected;
    if (state.isConnected != connected) {
      emit(state.copyWith(isConnected: connected));
    }
  }

  @override
  Future<void> close() async {
    _disposed = true;
    _stopActivationPolling();
    _clockTimer?.cancel();
    await _batteryStateSub?.cancel();
    await _connectivitySub?.cancel();
    await _volumeSub?.cancel();
    await _audioDeviceSub?.cancel();
    await _chatSubscription?.cancel();
    await _systemService.dispose();
    return super.close();
  }

  String? _cleanWifiName(String? name) {
    if (name == null) {
      return null;
    }
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == '<unknown ssid>') {
      return null;
    }
    if (trimmed.length >= 2 &&
        trimmed.startsWith('"') &&
        trimmed.endsWith('"')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }
}

class _PrepareOutcome {
  const _PrepareOutcome._({
    required this.ready,
    required this.awaitingActivation,
    required this.activation,
    required this.errorMessage,
    required this.qtaUrl,
  });

  factory _PrepareOutcome.ready({required Activation? activation}) {
    return _PrepareOutcome._(
      ready: true,
      awaitingActivation: false,
      activation: activation,
      errorMessage: null,
      qtaUrl: null,
    );
  }

  factory _PrepareOutcome.awaitingActivation({
    required Activation activation,
    required String qtaUrl,
  }) {
    return _PrepareOutcome._(
      ready: false,
      awaitingActivation: true,
      activation: activation,
      errorMessage: null,
      qtaUrl: qtaUrl,
    );
  }

  factory _PrepareOutcome.error(String message) {
    return _PrepareOutcome._(
      ready: false,
      awaitingActivation: false,
      activation: null,
      errorMessage: message,
      qtaUrl: null,
    );
  }

  final bool ready;
  final bool awaitingActivation;
  final Activation? activation;
  final String? errorMessage;
  final String? qtaUrl;
}
