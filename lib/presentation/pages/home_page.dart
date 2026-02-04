import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';

import '../../capabilities/protocol/protocol.dart';
import '../../core/config/app_config.dart';
import '../../core/permissions/permission_type.dart';
import '../../core/system/ota/model/ota_result.dart';
import '../../core/theme/forui/theme_tokens.dart';
import '../../features/chat/application/state/chat_cubit.dart';
import '../../features/chat/application/state/chat_state.dart';
import '../../features/chat/domain/entities/chat_message.dart';
import '../../features/home/application/state/home_cubit.dart';
import '../../features/home/application/state/home_state.dart';
import '../../features/home/domain/entities/home_system_status.dart';
import '../../features/home/domain/entities/home_wifi_network.dart';
import '../app/theme_mode_cubit.dart';
import '../app/theme_palette_cubit.dart';
import '../app/text_scale_cubit.dart';
import '../app/listening_mode_cubit.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/theme_palette.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../system/permissions/permission_state.dart';
import '../widgets/home/connection_status_banner.dart';
import '../widgets/home/emotion_palette.dart';
import '../widgets/home/home_content.dart';
import '../widgets/home/home_footer.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_settings_sheet.dart';
import '../widgets/home/wifi_password_sheet.dart';
import 'permission_sheet_content.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AudioPlayer _chimePlayer = AudioPlayer();
  late final Uint8List _chimeBytes = _buildChimeWavBytes();
  DateTime _lastChimeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _wasSpeaking = false;
  String _wifiPassword = '';
  bool _permissionSheetOpen = false;
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;
  final Map<FLayout, FPersistentSheetController> _settingsSheetControllers = {};
  bool _settingsSheetVisible = false;
  final ValueNotifier<bool> _cameraEnabled = ValueNotifier(false);
  final ValueNotifier<double> _cameraAspectRatio = ValueNotifier(4 / 3);

  @override
  void initState() {
    super.initState();
    context.read<HomeCubit>().initialize();
    if (AppConfig.permissionsEnabled) {
      _schedulePermissionPrompt();
    }
  }

  @override
  void dispose() {
    for (final controller in _settingsSheetControllers.values) {
      controller.dispose();
    }
    _cameraEnabled.dispose();
    _cameraAspectRatio.dispose();
    _chimePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<ListeningModeCubit, ListeningMode>(
          listener: (context, mode) {
            context.read<ChatCubit>().setListeningMode(mode);
          },
        ),
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (previous, current) =>
              previous.isSpeaking != current.isSpeaking,
          listener: (context, state) {
            if (_wasSpeaking && !state.isSpeaking) {
              _playChime();
            }
            _wasSpeaking = state.isSpeaking;
          },
        ),
        BlocListener<HomeCubit, HomeState>(
          listenWhen: (previous, current) =>
              (previous.isConnected != current.isConnected ||
              previous.errorMessage != current.errorMessage),
          listener: (context, state) {
            if (state.isConnected) {
              _playChime();
            }
            final error = state.errorMessage;
            if (error != null && error.isNotEmpty) {
              showFToast(
                context: context,
                alignment: FToastAlignment.topRight,
                icon: const Icon(FIcons.triangleAlert),
                title: const Text('Không thể kết nối'),
                description: Text(error),
              );
            }
          },
        ),
        BlocListener<PermissionCubit, PermissionState>(
          listenWhen: (previous, current) =>
              (previous.isReady != current.isReady ||
              previous.isChecking != current.isChecking),
          listener: (context, state) {
            _handlePermissionState(state);
          },
        ),
      ],
      child: _buildFullHome(context),
    );
  }

  Future<void> _handleConnectChat() async {
    if (AppConfig.permissionsEnabled) {
      final permissionState = context.read<PermissionCubit>().state;
      if (!permissionState.isReady) {
        await _openPermissionSheet();
        return;
      }
    }
    await context.read<HomeCubit>().connect();
  }

  Future<void> _handleDisconnectChat() async {
    await context.read<HomeCubit>().disconnect();
  }

  Future<void> _handleManualSend() async {
    await context.read<ChatCubit>().stopListening();
  }

  Future<void> _handleVolumeChanged(double value) async {
    await context.read<HomeCubit>().setVolume(value);
  }

  Widget _buildFullHome(BuildContext context) {
    _scheduleHeaderMeasure();
    return FScaffold(
      child: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                top: ThemeTokens.spaceXs,
                bottom: ThemeTokens.spaceSm,
              ),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      key: _headerKey,
                      width: double.infinity,
                      color: context.theme.brand.headerBackground,
                      padding: const EdgeInsets.all(8),
                      child: BlocSelector<
                        HomeCubit,
                        HomeState,
                        ({
                          DateTime now,
                          int? batteryLevel,
                          HomeBatteryState? batteryState,
                          List<HomeConnectivity>? connectivity,
                          double? volume,
                          HomeAudioDevice? audioDevice,
                          String? wifiName,
                          String? carrierName,
                          List<HomeWifiNetwork> wifiNetworks,
                          bool wifiLoading,
                          String? wifiError,
                        })
                      >(
                        selector: (state) => (
                          now: state.now,
                          batteryLevel: state.batteryLevel,
                          batteryState: state.batteryState,
                          connectivity: state.connectivity,
                          volume: state.volume,
                          audioDevice: state.audioDevice,
                          wifiName: state.wifiName,
                          carrierName: state.carrierName,
                          wifiNetworks: state.wifiNetworks,
                          wifiLoading: state.wifiLoading,
                          wifiError: state.wifiError,
                        ),
                        builder: (context, data) {
                          return HomeHeader(
                            now: data.now,
                            onOpenSettings: () => _openSettingsSheet(context),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: _headerSpacing()),
                  BlocSelector<
                    ChatCubit,
                    ChatState,
                    ({
                      String? emotion,
                      ChatConnectionStatus status,
                      bool isSpeaking,
                      double outgoing,
                      String? error,
                      bool networkWarning,
                    })
                  >(
                    selector: (state) => (
                      emotion: state.currentEmotion,
                      status: state.status,
                      isSpeaking: state.isSpeaking,
                      outgoing: state.outgoingLevel,
                      error: state.connectionError,
                      networkWarning: state.networkWarning,
                    ),
                    builder: (context, data) {
                      final palette = EmotionPalette.resolve(
                        context,
                        data.emotion,
                      );
                      final connectionData = ConnectionStatusData(
                        status: data.status,
                        isSpeaking: data.isSpeaking,
                        outgoingLevel: data.outgoing,
                        error: data.error,
                        networkWarning: data.networkWarning,
                      );
                      return Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _cameraEnabled,
                          builder: (context, cameraEnabled, _) {
                            return ValueListenableBuilder<double>(
                              valueListenable: _cameraAspectRatio,
                              builder: (context, cameraAspectRatio, _) {
                                return HomeContent(
                                  palette: palette,
                                  connectionData: connectionData,
                                  cameraEnabled: cameraEnabled,
                                  cameraAspectRatio: cameraAspectRatio,
                                  onCameraEnabledChanged: _setCameraEnabled,
                                );
                              },
                            );
                          },
                        ),
                      );
                    },
                  ),
                  SizedBox(height: _headerSpacing()),
                  BlocSelector<
                    HomeCubit,
                    HomeState,
                    ({
                      Activation? activation,
                      bool awaitingActivation,
                      double activationProgress,
                      bool isConnecting,
                      bool isConnected,
                    })
                  >(
                    selector: (state) => (
                      activation: state.activation,
                      awaitingActivation: state.awaitingActivation,
                      activationProgress: state.activationProgress,
                      isConnecting: state.isConnecting,
                      isConnected: state.isConnected,
                    ),
                    builder: (context, homeData) {
                      return BlocSelector<
                        ChatCubit,
                        ChatState,
                        ({
                          String? emotion,
                          ChatMessage? message,
                          int? ttsDurationMs,
                          String? ttsText,
                          double incoming,
                          double outgoing,
                          bool isSpeaking,
                        })
                      >(
                        selector: (state) => (
                          emotion: state.currentEmotion,
                          message: state.messages.isNotEmpty
                              ? state.messages.last
                              : null,
                          ttsDurationMs: state.lastTtsDurationMs,
                          ttsText: state.lastTtsText,
                          incoming: state.incomingLevel,
                          outgoing: state.outgoingLevel,
                          isSpeaking: state.isSpeaking,
                        ),
                        builder: (context, chatData) {
                          return BlocBuilder<
                            ListeningModeCubit,
                            ListeningMode
                          >(
                            builder: (context, listeningMode) {
                              return HomeFooter(
                                activation: homeData.activation,
                                awaitingActivation:
                                    homeData.awaitingActivation,
                                activationProgress:
                                    homeData.activationProgress,
                                onConnect: _handleConnectChat,
                                onDisconnect: _handleDisconnectChat,
                                onManualSend: _handleManualSend,
                                isConnecting: homeData.isConnecting,
                                isConnected: homeData.isConnected,
                                listeningMode: listeningMode,
                                currentEmotion: chatData.emotion,
                                lastMessage: chatData.message,
                                lastTtsDurationMs: chatData.ttsDurationMs,
                                lastTtsText: chatData.ttsText,
                                incomingLevel: chatData.incoming,
                                outgoingLevel: chatData.outgoing,
                                isSpeaking: chatData.isSpeaking,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          _buildSettingsBlur(context),
          _buildSettingsDismissBarrier(),
        ],
      ),
    );
  }

  Widget _buildSettingsBlur(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: true,
        child: AnimatedOpacity(
          opacity: _settingsSheetVisible ? 1 : 0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: BackdropFilter(
            filter: ImageFilter.compose(
              outer: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              inner: ColorFilter.mode(
                context.theme.colors.barrier,
                BlendMode.srcOver,
              ),
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsDismissBarrier() {
    if (!_settingsSheetVisible) {
      return const SizedBox.shrink();
    }
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissSettingsSheet,
        child: const SizedBox.expand(),
      ),
    );
  }

  void _dismissSettingsSheet() {
    const side = FLayout.btt;
    final controller = _settingsSheetControllers[side];
    if (controller == null) {
      return;
    }
    final isOpen = controller.status == AnimationStatus.completed ||
        controller.status == AnimationStatus.forward;
    if (isOpen) {
      if (mounted) {
        setState(() {
          _settingsSheetVisible = false;
        });
      }
      controller.toggle();
    }
  }

  Future<void> _openWifiSettings() async {
    await context.read<HomeCubit>().openWifiSettings();
  }

  void _schedulePermissionPrompt() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _handlePermissionState(context.read<PermissionCubit>().state);
    });
  }

  void _handlePermissionState(PermissionState state) {
    if (!AppConfig.permissionsEnabled) {
      return;
    }
    if (state.isReady) {
      _closePermissionSheetIfOpen();
      return;
    }
    if (state.isChecking) {
      return;
    }
    _openPermissionSheet();
  }

  Future<void> _openPermissionSheet() async {
    if (_permissionSheetOpen || !mounted) {
      return;
    }
    _permissionSheetOpen = true;
    await showFSheet<void>(
      context: context,
      side: FLayout.btt,
      useRootNavigator: true,
      useSafeArea: true,
      resizeToAvoidBottomInset: true,
      barrierDismissible: false,
      mainAxisMaxRatio: null,
      draggable: true,
      builder: (context) => PermissionSheetContent(
        onAllow: _requestPermission,
        onNotNow: _handlePermissionNotNow,
      ),
    ).whenComplete(() {
      _permissionSheetOpen = false;
    });
  }

  Future<void> _requestPermission(PermissionType type) async {
    await context.read<PermissionCubit>().requestPermission(type);
  }

  void _handlePermissionNotNow() {
    _closePermissionSheetIfOpen();
  }

  void _closePermissionSheetIfOpen() {
    if (!_permissionSheetOpen || !mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
  }

  void _scheduleHeaderMeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final context = _headerKey.currentContext;
      if (context == null) {
        return;
      }
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) {
        return;
      }
      final height = box.size.height;
      if ((height - _headerHeight).abs() < 1) {
        return;
      }
      setState(() {
        _headerHeight = height;
      });
    });
  }

  Future<void> _playChime() async {
    final now = DateTime.now();
    if (now.difference(_lastChimeAt) < const Duration(milliseconds: 500)) {
      return;
    }
    _lastChimeAt = now;
    try {
      await _chimePlayer.play(BytesSource(_chimeBytes), volume: 1.0);
    } catch (_) {}
  }

  Uint8List _buildChimeWavBytes() {
    const sampleRate = 16000;
    const toneMs = 90;
    const gapMs = 40;
    final tone1 = _sineWave(
      sampleRate: sampleRate,
      frequency: 880,
      durationMs: toneMs,
    );
    final tone2 = _sineWave(
      sampleRate: sampleRate,
      frequency: 1320,
      durationMs: toneMs,
    );
    final gapSamples = (sampleRate * gapMs / 1000).round();
    final gap = List<int>.filled(gapSamples, 0);
    final pcm = <int>[...tone1, ...gap, ...tone2];
    return _wavFromPcm16(pcm, sampleRate);
  }

  List<int> _sineWave({
    required int sampleRate,
    required double frequency,
    required int durationMs,
  }) {
    final samples = (sampleRate * durationMs / 1000).round();
    final data = List<int>.filled(samples, 0);
    final omega = 2 * math.pi * frequency / sampleRate;
    for (var i = 0; i < samples; i++) {
      final value = math.sin(omega * i);
      data[i] = (value * 0.6 * 32767).round();
    }
    return data;
  }

  Uint8List _wavFromPcm16(List<int> samples, int sampleRate) {
    final byteRate = sampleRate * 2;
    final blockAlign = 2;
    final dataSize = samples.length * 2;
    final buffer = BytesBuilder();
    buffer.add(_ascii('RIFF'));
    buffer.add(_int32le(36 + dataSize));
    buffer.add(_ascii('WAVE'));
    buffer.add(_ascii('fmt '));
    buffer.add(_int32le(16));
    buffer.add(_int16le(1));
    buffer.add(_int16le(1));
    buffer.add(_int32le(sampleRate));
    buffer.add(_int32le(byteRate));
    buffer.add(_int16le(blockAlign));
    buffer.add(_int16le(16));
    buffer.add(_ascii('data'));
    buffer.add(_int32le(dataSize));
    final pcm = ByteData(dataSize);
    for (var i = 0; i < samples.length; i++) {
      pcm.setInt16(i * 2, samples[i], Endian.little);
    }
    buffer.add(pcm.buffer.asUint8List());
    return buffer.takeBytes();
  }

  Uint8List _ascii(String value) => Uint8List.fromList(value.codeUnits);

  Uint8List _int16le(int value) {
    final data = ByteData(2)..setInt16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _int32le(int value) {
    final data = ByteData(4)..setInt32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  double _headerSpacing() {
    if (_headerHeight <= 0) {
      return ThemeTokens.spaceSm;
    }
    final spacing = _headerHeight * 0.1;
    return spacing.clamp(ThemeTokens.spaceSm, ThemeTokens.spaceMd);
  }

  Future<void> _refreshWifiNetworks() async {
    await context.read<HomeCubit>().refreshWifiNetworks();
  }

  void _openWifiPasswordSheet(HomeWifiNetwork network) {
    _wifiPassword = '';
    showFSheet(
      context: context,
      side: FLayout.btt,
      mainAxisMaxRatio: 0.55,
      barrierDismissible: false,
      draggable: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            var isConnecting = false;
            Future<void> connect() async {
              setModalState(() {
                isConnecting = true;
              });
              final success = await context.read<HomeCubit>().connectToWifi(
                network,
                _wifiPassword,
              );
              if (!mounted || !context.mounted) {
                return;
              }
              setModalState(() {
                isConnecting = false;
              });
              if (success) {
                Navigator.of(context).pop();
                _refreshWifiNetworks();
                await _refreshNetworkStatus();
                if (!mounted) {
                  return;
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã gửi yêu cầu kết nối Wi‑Fi'),
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kết nối Wi‑Fi thất bại')),
                  );
                }
              }
            }

            return WifiPasswordSheet(
              network: network,
              password: _wifiPassword,
              onPasswordChanged: (value) {
                setModalState(() {
                  _wifiPassword = value;
                });
              },
              onConnect: isConnecting ? null : connect,
              onCancel: () => Navigator.of(context).pop(),
              isConnecting: isConnecting,
            );
          },
        );
      },
    );
  }

  Future<void> _refreshNetworkStatus() async {
    await context.read<HomeCubit>().refreshNetworkStatus();
  }

  Future<void> _openSettingsSheet(BuildContext sheetContext) async {
    await _refreshWifiNetworks();
    if (!mounted || !sheetContext.mounted) {
      return;
    }
    const side = FLayout.btt;
    for (final MapEntry(:key, :value) in _settingsSheetControllers.entries) {
      if (key != side && value.status == AnimationStatus.completed) {
        return;
      }
    }
    var controller = _settingsSheetControllers[side];
    if (controller == null) {
      setState(() {
        _settingsSheetVisible = true;
      });
      controller = _settingsSheetControllers[side] ??= showFPersistentSheet(
        context: sheetContext,
        side: side,
        keepAliveOffstage: true,
        onClosing: () {
          if (!mounted) {
            return;
          }
          setState(() {
            _settingsSheetVisible = false;
          });
        },
        builder: (context, controller) => Container(
          height: double.infinity,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.theme.colors.background,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(ThemeTokens.radiusMd),
            ),
            border: Border.symmetric(
              horizontal: BorderSide(color: context.theme.colors.border),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: BlocBuilder<ThemeModeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return BlocBuilder<ThemePaletteCubit, AppThemePalette>(
                  builder: (context, themePalette) {
                    return BlocBuilder<TextScaleCubit, double>(
                      builder: (context, textScale) {
                        return BlocBuilder<ListeningModeCubit, ListeningMode>(
                          builder: (context, listeningMode) {
                            return BlocSelector<
                              HomeCubit,
                              HomeState,
                              ({
                                double? volume,
                                HomeAudioDevice? audioDevice,
                                List<HomeConnectivity>? connectivity,
                                String? wifiName,
                                String? carrierName,
                                List<HomeWifiNetwork> wifiNetworks,
                                bool wifiLoading,
                                String? wifiError,
                                int? batteryLevel,
                                HomeBatteryState? batteryState,
                              })
                            >(
                              selector: (state) => (
                                volume: state.volume,
                                audioDevice: state.audioDevice,
                                connectivity: state.connectivity,
                                wifiName: state.wifiName,
                                carrierName: state.carrierName,
                                wifiNetworks: state.wifiNetworks,
                                wifiLoading: state.wifiLoading,
                                wifiError: state.wifiError,
                                batteryLevel: state.batteryLevel,
                                batteryState: state.batteryState,
                              ),
                              builder: (context, data) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: _cameraEnabled,
                                  builder: (context, cameraEnabled, _) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _cameraAspectRatio,
                                      builder:
                                          (context, cameraAspectRatio, _) {
                                        return HomeSettingsSheet(
                                          volume: data.volume,
                                          audioDevice: data.audioDevice,
                                          connectivity: data.connectivity,
                                          wifiName: data.wifiName,
                                          carrierName: data.carrierName,
                                          wifiNetworks: data.wifiNetworks,
                                          wifiLoading: data.wifiLoading,
                                          wifiError: data.wifiError,
                                          batteryLevel: data.batteryLevel,
                                          batteryState: data.batteryState,
                                          onWifiRefresh: _refreshWifiNetworks,
                                          onWifiSettings: _openWifiSettings,
                                          onWifiSelect: _openWifiPasswordSheet,
                                          onVolumeChanged: _handleVolumeChanged,
                                          textScale: textScale,
                                          onTextScaleChanged: sheetContext
                                              .read<TextScaleCubit>()
                                              .setScale,
                                          cameraEnabled: cameraEnabled,
                                          onCameraEnabledChanged:
                                              _setCameraEnabled,
                                          cameraAspectRatio: cameraAspectRatio,
                                          onCameraAspectChanged:
                                              _setCameraAspectRatio,
                                          themeMode: themeMode,
                                          themePalette: themePalette,
                                          onThemePaletteChanged: sheetContext
                                              .read<ThemePaletteCubit>()
                                              .setPalette,
                                          onSetLight: sheetContext
                                              .read<ThemeModeCubit>()
                                              .setLight,
                                          onSetDark: sheetContext
                                              .read<ThemeModeCubit>()
                                              .setDark,
                                          listeningMode: listeningMode,
                                          onListeningModeChanged: sheetContext
                                              .read<ListeningModeCubit>()
                                              .setMode,
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ),
      );
      return;
    }

    final isOpen = controller.status == AnimationStatus.completed ||
        controller.status == AnimationStatus.forward;
    setState(() {
      _settingsSheetVisible = !isOpen;
    });
    controller.toggle();
  }

  void _setCameraEnabled(bool enabled) {
    if (_cameraEnabled.value == enabled) {
      return;
    }
    _cameraEnabled.value = enabled;
  }

  void _setCameraAspectRatio(double aspectRatio) {
    final next = aspectRatio.clamp(0.5, 2.0);
    if ((next - _cameraAspectRatio.value).abs() < 0.001) {
      return;
    }
    _cameraAspectRatio.value = next;
  }
}
