import 'package:audio_router/audio_router.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../../core/system/ota/model/ota_result.dart';
import '../../domain/entities/home_wifi_network.dart';

class HomeState {
  const HomeState({
    required this.now,
    required this.isConnecting,
    required this.isConnected,
    required this.awaitingActivation,
    required this.activationProgress,
    required this.activation,
    required this.errorMessage,
    required this.batteryLevel,
    required this.batteryState,
    required this.connectivity,
    required this.wifiName,
    required this.carrierName,
    required this.volume,
    required this.audioDevice,
    required this.wifiNetworks,
    required this.wifiLoading,
    required this.wifiError,
  });

  factory HomeState.initial() {
    return HomeState(
      now: _epoch,
      isConnecting: false,
      isConnected: false,
      awaitingActivation: false,
      activationProgress: 0,
      activation: null,
      errorMessage: null,
      batteryLevel: null,
      batteryState: null,
      connectivity: null,
      wifiName: null,
      carrierName: null,
      volume: null,
      audioDevice: null,
      wifiNetworks: <HomeWifiNetwork>[],
      wifiLoading: false,
      wifiError: null,
    );
  }

  final DateTime now;
  final bool isConnecting;
  final bool isConnected;
  final bool awaitingActivation;
  final double activationProgress;
  final Activation? activation;
  final String? errorMessage;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final List<ConnectivityResult>? connectivity;
  final String? wifiName;
  final String? carrierName;
  final double? volume;
  final AudioDevice? audioDevice;
  final List<HomeWifiNetwork> wifiNetworks;
  final bool wifiLoading;
  final String? wifiError;

  HomeState copyWith({
    DateTime? now,
    bool? isConnecting,
    bool? isConnected,
    bool? awaitingActivation,
    double? activationProgress,
    Object? activation = _noChange,
    Object? errorMessage = _noChange,
    int? batteryLevel,
    Object? batteryState = _noChange,
    List<ConnectivityResult>? connectivity,
    Object? wifiName = _noChange,
    Object? carrierName = _noChange,
    Object? volume = _noChange,
    Object? audioDevice = _noChange,
    List<HomeWifiNetwork>? wifiNetworks,
    bool? wifiLoading,
    Object? wifiError = _noChange,
  }) {
    final nextActivation = activation == _noChange
        ? this.activation
        : activation as Activation?;
    final nextError = errorMessage == _noChange
        ? this.errorMessage
        : errorMessage as String?;
    final nextBatteryState = batteryState == _noChange
        ? this.batteryState
        : batteryState as BatteryState?;
    final nextWifiName = wifiName == _noChange ? this.wifiName : wifiName as String?;
    final nextCarrierName =
        carrierName == _noChange ? this.carrierName : carrierName as String?;
    final nextVolume = volume == _noChange ? this.volume : volume as double?;
    final nextAudioDevice = audioDevice == _noChange
        ? this.audioDevice
        : audioDevice as AudioDevice?;
    final nextWifiError =
        wifiError == _noChange ? this.wifiError : wifiError as String?;
    return HomeState(
      now: now ?? this.now,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      awaitingActivation: awaitingActivation ?? this.awaitingActivation,
      activationProgress: activationProgress ?? this.activationProgress,
      activation: nextActivation,
      errorMessage: nextError,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      batteryState: nextBatteryState,
      connectivity: connectivity ?? this.connectivity,
      wifiName: nextWifiName,
      carrierName: nextCarrierName,
      volume: nextVolume,
      audioDevice: nextAudioDevice,
      wifiNetworks: wifiNetworks ?? this.wifiNetworks,
      wifiLoading: wifiLoading ?? this.wifiLoading,
      wifiError: nextWifiError,
    );
  }

  static const Object _noChange = Object();
  static final DateTime _epoch = DateTime.fromMillisecondsSinceEpoch(0);
}
