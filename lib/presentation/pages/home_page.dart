import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
// import 'package:flutter/services.dart';

import '../../capabilities/protocol/protocol.dart';
import '../../capabilities/voice/session_coordinator.dart';
import '../../capabilities/web_host/local_web_host_service.dart';
import '../../core/config/app_config.dart';
import '../../core/config/default_settings.dart';
import '../../core/system/ota/model/ota_result.dart';
import '../../core/theme/forui/theme_tokens.dart';
import '../../di/locator.dart';
import '../../core/permissions/permission_status.dart';
import '../../core/permissions/permission_type.dart';
import '../../features/chat/application/state/chat_cubit.dart';
import '../../features/chat/application/state/chat_state.dart';
import '../../features/chat/domain/entities/chat_message.dart';
import '../../features/chat/domain/entities/related_chat_image.dart';
import '../../features/home/application/state/home_cubit.dart';
import '../../features/home/application/state/home_state.dart';
import '../../features/home/domain/entities/home_system_status.dart';
import '../../features/home/domain/entities/home_wifi_network.dart';
import '../app/theme_mode_cubit.dart';
import '../app/theme_palette_cubit.dart';
import '../app/text_scale_cubit.dart';
import '../app/listening_mode_cubit.dart';
import '../app/carousel_settings_cubit.dart';
import '../app/text_send_mode_cubit.dart';
import '../app/connect_greeting_cubit.dart';
import '../app/auto_reconnect_cubit.dart';
import '../app/face_detection_settings_cubit.dart';
import '../app/device_mac_cubit.dart';
import '../app/update_cubit.dart';
import '../../theme/theme_extensions.dart';
import '../../theme/theme_palette.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../system/permissions/permission_state.dart';
import '../widgets/home/emotion_palette.dart';
import '../widgets/home/home_camera_overlay.dart';
import '../widgets/home/home_content.dart';
import '../widgets/home/home_footer.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/home_settings_sheet.dart';
import '../widgets/home/wifi_password_sheet.dart';
import '../../routing/routes.dart';
import '../../system/update/github_updater.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  DateTime _lastChimeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _wasSpeaking = false;
  String _wifiPassword = '';
  bool _isRequestingPermissions = false;
  bool _hasRequestedPermissionsOnce = false;
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;
  bool _headerMeasureScheduled = false;
  final Map<FLayout, FPersistentSheetController> _settingsSheetControllers = {};
  bool _settingsSheetVisible = false;
  bool _updateRequested = false;
  final ValueNotifier<bool> _cameraEnabled = ValueNotifier(false);
  final ValueNotifier<double> _cameraAspectRatio = ValueNotifier(4 / 3);
  final ValueNotifier<bool> _detectFacesEnabled = ValueNotifier(true);
  // static const MethodChannel _kioskChannel = MethodChannel('voicebot/kiosk');
  final ValueNotifier<double?> _faceConnectProgress = ValueNotifier<double?>(
    null,
  );
  Timer? _faceConnectTimer;
  Timer? _carouselHideTimer;
  bool _facePresent = false;
  List<String> _carouselImages = const <String>[];
  bool _landscapeWsActionInFlight = false;
  static const Duration _faceConnectDelay = Duration(seconds: 3);
  static const Duration _carouselDisplayDuration = Duration(minutes: 2);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // unawaited(_enterKioskMode());
    final hostStart = LocalWebHostService.instance.start(preferredPort: 8080);
    unawaited(hostStart);
    context.read<HomeCubit>().initialize();
    context.read<ChatCubit>().setTextSendMode(
      context.read<TextSendModeCubit>().state,
    );
    context.read<ChatCubit>().setConnectGreeting(
      context.read<ConnectGreetingCubit>().state,
    );
    context.read<ChatCubit>().setAutoReconnectEnabled(
      context.read<AutoReconnectCubit>().state,
    );
    final defaults = DefaultSettingsRegistry.current;
    _cameraEnabled.value = defaults.camera.enabled;
    _cameraAspectRatio.value = defaults.camera.aspectRatio;
    _detectFacesEnabled.value = defaults.camera.detectFaces;
    if (defaults.app.permissionsEnabled) {
      _schedulePermissionPrompt();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final controller in _settingsSheetControllers.values) {
      controller.dispose();
    }
    _cameraEnabled.dispose();
    _cameraAspectRatio.dispose();
    _detectFacesEnabled.dispose();
    _faceConnectProgress.dispose();
    _faceConnectTimer?.cancel();
    _carouselHideTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) {
      return;
    }
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshNetworkStatus());
      if (_settingsSheetVisible) {
        unawaited(_refreshWifiNetworks());
      }
    }
  }

  bool _lastWasSpeakingLandscape = false;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      final shortestSide = screenWidth < screenHeight
          ? screenWidth
          : screenHeight;
      final fontSize = (shortestSide / 30).clamp(12.0, 20.0);
      final padding = (shortestSide / 40).clamp(8.0, 24.0);
      final cameraSize = (shortestSide / 3).clamp(120.0, 200.0);

      final cameraAspectRatio = _cameraAspectRatio.value;

      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: BlocBuilder<ChatCubit, ChatState>(
            builder: (context, chatState) {
              final bool isSpeakingNow = chatState.isSpeaking;

              if (_lastWasSpeakingLandscape && !isSpeakingNow) {
                _playChime();
              }

              if (isSpeakingNow) {
                _lastWasSpeakingLandscape = true;
              } else if (chatState.outgoingLevel > 0.01) {
                _lastWasSpeakingLandscape = false;
              }

              return Stack(
                children: [
                  Positioned(
                    top: padding * 0.5,
                    left: padding * 0.75,
                    child: _buildLandscapeConnectionButton(
                      status: chatState.status,
                      fontSize: fontSize,
                      padding: padding,
                      inFlight: _landscapeWsActionInFlight,
                    ),
                  ),
                  Positioned(
                    bottom: padding * 2,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildEmotionSelector(
                        chatState.currentEmotion,
                        fontSize,
                        padding,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      SizedBox(height: padding),
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: _buildConnectionStatusBadge(
                            status: chatState.status,
                            isSpeaking: chatState.isSpeaking,
                            isListening: chatState.outgoingLevel > 0.01,
                            connectionError: chatState.connectionError,
                            networkWarning: chatState.networkWarning,
                            fontSize: fontSize,
                            padding: padding,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _buildChatMessagesList(
                          chatState.messages,
                          fontSize,
                          padding,
                        ),
                      ),
                    ],
                  ),
                  _buildLandscapeCameraPanel(
                    cameraSize: cameraSize,
                    cameraAspectRatio: cameraAspectRatio,
                    fontSize: fontSize,
                    padding: padding,
                  ),
                ],
              );
            },
          ),
        ),
      );
    }

    return MultiBlocListener(
      listeners: [
        BlocListener<ListeningModeCubit, ListeningMode>(
          listener: (context, mode) {
            context.read<ChatCubit>().setListeningMode(mode);
          },
        ),
        BlocListener<TextSendModeCubit, TextSendMode>(
          listener: (context, mode) {
            context.read<ChatCubit>().setTextSendMode(mode);
          },
        ),
        BlocListener<ConnectGreetingCubit, String>(
          listener: (context, greeting) {
            context.read<ChatCubit>().setConnectGreeting(greeting);
          },
        ),
        BlocListener<AutoReconnectCubit, bool>(
          listener: (context, enabled) {
            context.read<ChatCubit>().setAutoReconnectEnabled(enabled);
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
        BlocListener<ChatCubit, ChatState>(
          listenWhen: (previous, current) =>
              _relatedImagesSignature(previous.messages) !=
              _relatedImagesSignature(current.messages),
          listener: (context, state) {
            _syncCarouselWithRelatedImages(state.messages);
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
            _detectFacesEnabled.value =
                !state.isConnected && !state.isConnecting;
            if (state.isConnected || state.isConnecting) {
              _stopFaceCountdown();
            } else if (_facePresent) {
              _startFaceCountdown();
            }
            final error = state.errorMessage;
            if (error != null && error.isNotEmpty) {
              _showErrorToast(error);
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
        BlocListener<UpdateCubit, UpdateDownloadState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            _handleUpdateDownloadState(state);
          },
        ),
      ],
      child: _buildFullHome(context),
    );
  }

  Future<void> _handleConnectChat() async {
    final homeCubit = context.read<HomeCubit>();
    final permissionCubit = context.read<PermissionCubit>();
    if (DefaultSettingsRegistry.current.app.permissionsEnabled) {
      await _requestSystemPermissions(force: true);
      final permissionState = permissionCubit.state;
      if (!permissionState.isReady) {
        _showPermissionRequiredToast(permissionState);
        return;
      }
    }
    await homeCubit.connect();
  }

  Future<void> _handleDisconnectChat() async {
    await context.read<HomeCubit>().disconnect();
  }

  Future<void> _toggleLandscapeWsConnection(ChatConnectionStatus status) async {
    if (_landscapeWsActionInFlight || !mounted) {
      return;
    }
    if (status == ChatConnectionStatus.connecting ||
        status == ChatConnectionStatus.reconnecting) {
      return;
    }
    setState(() {
      _landscapeWsActionInFlight = true;
    });
    try {
      if (status == ChatConnectionStatus.connected) {
        await _handleDisconnectChat();
        return;
      }
      await _handleConnectChat();
    } finally {
      if (mounted) {
        setState(() {
          _landscapeWsActionInFlight = false;
        });
      }
    }
  }

  Future<void> _handleManualSend() async {
    await context.read<ChatCubit>().stopListening();
  }

  // Future<void> _enterKioskMode() async {
  //   try {
  //     await _kioskChannel.invokeMethod<void>('startLockTask');
  //   } catch (_) {}
  // }

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
                    borderRadius: BorderRadius.circular(ThemeTokens.radiusSm),
                    child: Container(
                      key: _headerKey,
                      width: double.infinity,
                      color: context.theme.brand.headerBackground,
                      padding: const EdgeInsets.all(ThemeTokens.spaceSm),
                      child:
                          BlocSelector<
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
                                onOpenSettings: () =>
                                    _openSettingsSheet(context),
                                onCheckUpdate: _checkForUpdates,
                              );
                            },
                          ),
                    ),
                  ),
                  SizedBox(height: _headerSpacing()),
                  BlocSelector<ChatCubit, ChatState, String?>(
                    selector: (state) => state.currentEmotion,
                    builder: (context, emotion) {
                      final palette = EmotionPalette.resolve(context, emotion);
                      return Expanded(
                        child: BlocBuilder<CarouselSettingsCubit, CarouselSettings>(
                          builder: (context, carouselSettings) {
                            return BlocBuilder<
                              FaceDetectionSettingsCubit,
                              FaceDetectionSettings
                            >(
                              builder: (context, faceSettings) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: _cameraEnabled,
                                  builder: (context, cameraEnabled, _) {
                                    return ValueListenableBuilder<double>(
                                      valueListenable: _cameraAspectRatio,
                                      builder: (context, cameraAspectRatio, _) {
                                        return ValueListenableBuilder<bool>(
                                          valueListenable: _detectFacesEnabled,
                                          builder: (context, detectFaces, _) {
                                            return HomeContent(
                                              palette: palette,
                                              currentEmotion: emotion,
                                              carouselImages: _carouselImages,
                                              cameraEnabled: cameraEnabled,
                                              cameraAspectRatio:
                                                  cameraAspectRatio,
                                              onCameraEnabledChanged:
                                                  _setCameraEnabled,
                                              onFacePresenceChanged:
                                                  _handleFacePresenceChanged,
                                              detectFacesEnabled: detectFaces,
                                              faceLandmarksEnabled:
                                                  faceSettings.landmarksEnabled,
                                              faceMeshEnabled:
                                                  faceSettings.meshEnabled,
                                              eyeTrackingEnabled: faceSettings
                                                  .eyeTrackingEnabled,
                                              carouselHeight:
                                                  carouselSettings.height,
                                              carouselAutoPlay:
                                                  carouselSettings.autoPlay,
                                              carouselAutoPlayInterval:
                                                  carouselSettings
                                                      .autoPlayInterval,
                                              carouselAnimationDuration:
                                                  carouselSettings
                                                      .animationDuration,
                                              carouselViewportFraction:
                                                  carouselSettings
                                                      .viewportFraction,
                                              carouselEnlargeCenter:
                                                  carouselSettings
                                                      .enlargeCenter,
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
                        })
                      >(
                        selector: (state) => (
                          emotion: state.currentEmotion,
                          message: _lastTranscriptMessage(state.messages),
                          ttsDurationMs: state.lastTtsDurationMs,
                          ttsText: state.lastTtsText,
                        ),
                        builder: (context, chatData) {
                          return BlocBuilder<ListeningModeCubit, ListeningMode>(
                            builder: (context, listeningMode) {
                              return ValueListenableBuilder<double?>(
                                valueListenable: _faceConnectProgress,
                                builder: (context, progress, _) {
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
                                    showConnectButton: true,
                                    listeningMode: listeningMode,
                                    currentEmotion: chatData.emotion,
                                    lastMessage: chatData.message,
                                    lastTtsDurationMs: chatData.ttsDurationMs,
                                    lastTtsText: chatData.ttsText,
                                    faceConnectProgress: progress,
                                  );
                                },
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

  ChatMessage? _lastTranscriptMessage(List<ChatMessage> messages) {
    for (var index = messages.length - 1; index >= 0; index -= 1) {
      final message = messages[index];
      if (message.type != ChatMessageType.text) {
        continue;
      }
      if (message.text.trim().isEmpty) {
        continue;
      }
      return message;
    }
    return null;
  }

  void _dismissSettingsSheet() {
    const side = FLayout.btt;
    final controller = _settingsSheetControllers[side];
    if (controller == null) {
      return;
    }
    final isOpen =
        controller.status == AnimationStatus.completed ||
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
    if (!DefaultSettingsRegistry.current.app.permissionsEnabled) {
      return;
    }
    if (state.isReady) {
      return;
    }
    if (state.isChecking) {
      return;
    }
    unawaited(_requestSystemPermissions());
  }

  Future<void> _requestSystemPermissions({bool force = false}) async {
    final permissionCubit = context.read<PermissionCubit>();
    if (!mounted || _isRequestingPermissions) {
      return;
    }
    if (!force && _hasRequestedPermissionsOnce) {
      return;
    }
    if (!force) {
      _hasRequestedPermissionsOnce = true;
    }
    _isRequestingPermissions = true;
    try {
      await permissionCubit.requestRequiredPermissions();
    } finally {
      _isRequestingPermissions = false;
    }
  }

  void _showPermissionRequiredToast(PermissionState state) {
    final missingPermissions = PermissionState.requiredPermissions
        .where((type) => state.statuses[type] != PermissionStatus.granted)
        .map(_permissionLabel)
        .toList(growable: false);
    final permissionList = missingPermissions.isEmpty
        ? 'cần thiết'
        : missingPermissions.join(', ');
    final message = state.hasPermanentlyDenied
        ? 'Quyền $permissionList đang bị chặn vĩnh viễn. Vui lòng bật lại trong Cài đặt hệ thống.'
        : 'Cần cấp quyền $permissionList để tiếp tục.';
    _showErrorToast(message);
  }

  String _permissionLabel(PermissionType permission) {
    return switch (permission) {
      PermissionType.microphone => 'micro',
      PermissionType.wifi => 'Wi-Fi',
      PermissionType.audio => 'audio',
      PermissionType.bluetooth => 'bluetooth',
      PermissionType.bluetoothScan => 'quét bluetooth',
      PermissionType.bluetoothConnect => 'kết nối bluetooth',
      PermissionType.file => 'tệp',
      PermissionType.camera => 'camera',
      PermissionType.photos => 'thư viện ảnh',
      PermissionType.notifications => 'thông báo',
    };
  }

  void _showErrorToast(String message) {
    if (!mounted || message.trim().isEmpty) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _scheduleHeaderMeasure() {
    if (_headerMeasureScheduled) {
      return;
    }
    _headerMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _headerMeasureScheduled = false;
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
      await getIt<SessionCoordinator>().playChime();
    } catch (_) {}
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

  void _syncCarouselWithRelatedImages(List<ChatMessage> messages) {
    final message = _findRelatedImagesMessage(messages);
    if (message == null || message.relatedImages.isEmpty) {
      _clearCarouselImages();
      return;
    }
    final urls = _extractRelatedImageUrls(message.relatedImages);
    if (urls.isEmpty) {
      _clearCarouselImages();
      return;
    }
    _carouselHideTimer?.cancel();
    if (!mounted) {
      return;
    }
    setState(() {
      _carouselImages = List<String>.unmodifiable(urls);
    });
    _carouselHideTimer = Timer(_carouselDisplayDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _carouselImages = const <String>[];
      });
    });
  }

  ChatMessage? _findRelatedImagesMessage(List<ChatMessage> messages) {
    for (var i = messages.length - 1; i >= 0; i -= 1) {
      final message = messages[i];
      if (message.type == ChatMessageType.relatedImages) {
        return message;
      }
    }
    return null;
  }

  String _relatedImagesSignature(List<ChatMessage> messages) {
    final message = _findRelatedImagesMessage(messages);
    if (message == null) {
      return 'none';
    }
    final query = message.relatedQuery ?? '';
    return [
      message.timestamp.microsecondsSinceEpoch.toString(),
      query,
      message.relatedImages.length.toString(),
    ].join('|');
  }

  List<String> _extractRelatedImageUrls(List<RelatedChatImage> images) {
    final urls = <String>[];
    final seen = <String>{};
    for (final image in images) {
      final raw = image.url.trim();
      if (raw.isEmpty) {
        continue;
      }
      if (seen.add(raw)) {
        urls.add(raw);
        if (urls.length >= AppConfig.homeCarouselMaxImages) {
          break;
        }
      }
    }
    return urls;
  }

  void _clearCarouselImages() {
    _carouselHideTimer?.cancel();
    _carouselHideTimer = null;
    if (_carouselImages.isEmpty || !mounted) {
      return;
    }
    setState(() {
      _carouselImages = const <String>[];
    });
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
            padding: const EdgeInsets.symmetric(
              horizontal: ThemeTokens.spaceMd,
              vertical: ThemeTokens.spaceSm,
            ),
            child: BlocBuilder<ThemeModeCubit, ThemeMode>(
              builder: (context, themeMode) {
                return BlocBuilder<ThemePaletteCubit, AppThemePalette>(
                  builder: (context, themePalette) {
                    return BlocBuilder<TextScaleCubit, double>(
                      builder: (context, textScale) {
                        return BlocBuilder<ListeningModeCubit, ListeningMode>(
                          builder: (context, listeningMode) {
                            return BlocBuilder<TextSendModeCubit, TextSendMode>(
                              builder: (context, textSendMode) {
                                return BlocBuilder<
                                  ConnectGreetingCubit,
                                  String
                                >(
                                  builder: (context, connectGreeting) {
                                    return BlocBuilder<
                                      AutoReconnectCubit,
                                      bool
                                    >(
                                      builder: (context, autoReconnectEnabled) {
                                        return BlocBuilder<
                                          CarouselSettingsCubit,
                                          CarouselSettings
                                        >(
                                          builder: (context, carouselSettings) {
                                            return BlocBuilder<
                                              FaceDetectionSettingsCubit,
                                              FaceDetectionSettings
                                            >(
                                              builder: (context, faceSettings) {
                                                return BlocSelector<
                                                  HomeCubit,
                                                  HomeState,
                                                  ({
                                                    double? volume,
                                                    HomeAudioDevice?
                                                    audioDevice,
                                                    List<HomeConnectivity>?
                                                    connectivity,
                                                    String? wifiName,
                                                    String? carrierName,
                                                    List<HomeWifiNetwork>
                                                    wifiNetworks,
                                                    bool wifiLoading,
                                                    String? wifiError,
                                                    int? batteryLevel,
                                                    HomeBatteryState?
                                                    batteryState,
                                                  })
                                                >(
                                                  selector: (state) => (
                                                    volume: state.volume,
                                                    audioDevice:
                                                        state.audioDevice,
                                                    connectivity:
                                                        state.connectivity,
                                                    wifiName: state.wifiName,
                                                    carrierName:
                                                        state.carrierName,
                                                    wifiNetworks:
                                                        state.wifiNetworks,
                                                    wifiLoading:
                                                        state.wifiLoading,
                                                    wifiError: state.wifiError,
                                                    batteryLevel:
                                                        state.batteryLevel,
                                                    batteryState:
                                                        state.batteryState,
                                                  ),
                                                  builder: (context, data) {
                                                    return ValueListenableBuilder<
                                                      bool
                                                    >(
                                                      valueListenable:
                                                          _cameraEnabled,
                                                      builder: (context, cameraEnabled, _) {
                                                        return ValueListenableBuilder<
                                                          double
                                                        >(
                                                          valueListenable:
                                                              _cameraAspectRatio,
                                                          builder:
                                                              (
                                                                context,
                                                                cameraAspectRatio,
                                                                _,
                                                              ) {
                                                                return BlocBuilder<
                                                                  DeviceMacCubit,
                                                                  String
                                                                >(
                                                                  builder:
                                                                      (
                                                                        context,
                                                                        macAddress,
                                                                      ) {
                                                                        return HomeSettingsSheet(
                                                                          volume:
                                                                              data.volume,
                                                                          audioDevice:
                                                                              data.audioDevice,
                                                                          connectivity:
                                                                              data.connectivity,
                                                                          wifiName:
                                                                              data.wifiName,
                                                                          carrierName:
                                                                              data.carrierName,
                                                                          wifiNetworks:
                                                                              data.wifiNetworks,
                                                                          wifiLoading:
                                                                              data.wifiLoading,
                                                                          wifiError:
                                                                              data.wifiError,
                                                                          batteryLevel:
                                                                              data.batteryLevel,
                                                                          batteryState:
                                                                              data.batteryState,
                                                                          onWifiRefresh:
                                                                              _refreshWifiNetworks,
                                                                          onWifiSettings:
                                                                              _openWifiSettings,
                                                                          onWifiSelect:
                                                                              _openWifiPasswordSheet,
                                                                          onVolumeChanged:
                                                                              _handleVolumeChanged,
                                                                          textScale:
                                                                              textScale,
                                                                          onTextScaleChanged: sheetContext
                                                                              .read<
                                                                                TextScaleCubit
                                                                              >()
                                                                              .setScale,
                                                                          cameraEnabled:
                                                                              cameraEnabled,
                                                                          onCameraEnabledChanged:
                                                                              _setCameraEnabled,
                                                                          cameraAspectRatio:
                                                                              cameraAspectRatio,
                                                                          onCameraAspectChanged:
                                                                              _setCameraAspectRatio,
                                                                          faceLandmarksEnabled:
                                                                              faceSettings.landmarksEnabled,
                                                                          faceMeshEnabled:
                                                                              faceSettings.meshEnabled,
                                                                          eyeTrackingEnabled:
                                                                              faceSettings.eyeTrackingEnabled,
                                                                          onFaceLandmarksChanged: sheetContext
                                                                              .read<
                                                                                FaceDetectionSettingsCubit
                                                                              >()
                                                                              .setLandmarksEnabled,
                                                                          onFaceMeshChanged: sheetContext
                                                                              .read<
                                                                                FaceDetectionSettingsCubit
                                                                              >()
                                                                              .setMeshEnabled,
                                                                          onEyeTrackingChanged: sheetContext
                                                                              .read<
                                                                                FaceDetectionSettingsCubit
                                                                              >()
                                                                              .setEyeTrackingEnabled,
                                                                          themeMode:
                                                                              themeMode,
                                                                          themePalette:
                                                                              themePalette,
                                                                          onThemePaletteChanged: sheetContext
                                                                              .read<
                                                                                ThemePaletteCubit
                                                                              >()
                                                                              .setPalette,
                                                                          onSetLight: sheetContext
                                                                              .read<
                                                                                ThemeModeCubit
                                                                              >()
                                                                              .setLight,
                                                                          onSetDark: sheetContext
                                                                              .read<
                                                                                ThemeModeCubit
                                                                              >()
                                                                              .setDark,
                                                                          onSetSystem: sheetContext
                                                                              .read<
                                                                                ThemeModeCubit
                                                                              >()
                                                                              .setSystem,
                                                                          listeningMode:
                                                                              listeningMode,
                                                                          onListeningModeChanged: sheetContext
                                                                              .read<
                                                                                ListeningModeCubit
                                                                              >()
                                                                              .setMode,
                                                                          textSendMode:
                                                                              textSendMode,
                                                                          onTextSendModeChanged: sheetContext
                                                                              .read<
                                                                                TextSendModeCubit
                                                                              >()
                                                                              .setMode,
                                                                          connectGreeting:
                                                                              connectGreeting,
                                                                          onConnectGreetingChanged: sheetContext
                                                                              .read<
                                                                                ConnectGreetingCubit
                                                                              >()
                                                                              .setGreeting,
                                                                          autoReconnectEnabled:
                                                                              autoReconnectEnabled,
                                                                          onAutoReconnectChanged: sheetContext
                                                                              .read<
                                                                                AutoReconnectCubit
                                                                              >()
                                                                              .setEnabled,
                                                                          macAddress:
                                                                              macAddress,
                                                                          onMacAddressChanged: sheetContext
                                                                              .read<
                                                                                DeviceMacCubit
                                                                              >()
                                                                              .setMacAddress,
                                                                          carouselHeight:
                                                                              carouselSettings.height,
                                                                          carouselAutoPlay:
                                                                              carouselSettings.autoPlay,
                                                                          carouselAutoPlayInterval:
                                                                              carouselSettings.autoPlayInterval,
                                                                          carouselAnimationDuration:
                                                                              carouselSettings.animationDuration,
                                                                          carouselViewportFraction:
                                                                              carouselSettings.viewportFraction,
                                                                          carouselEnlargeCenter:
                                                                              carouselSettings.enlargeCenter,
                                                                          onCarouselHeightChanged: sheetContext
                                                                              .read<
                                                                                CarouselSettingsCubit
                                                                              >()
                                                                              .setHeight,
                                                                          onCarouselAutoPlayChanged: sheetContext
                                                                              .read<
                                                                                CarouselSettingsCubit
                                                                              >()
                                                                              .setAutoPlay,
                                                                          onCarouselIntervalChanged: sheetContext
                                                                              .read<
                                                                                CarouselSettingsCubit
                                                                              >()
                                                                              .setInterval,
                                                                          onCarouselAnimationChanged: sheetContext
                                                                              .read<
                                                                                CarouselSettingsCubit
                                                                              >()
                                                                              .setAnimationDuration,
                                                                          onCarouselViewportChanged: sheetContext
                                                                              .read<
                                                                                CarouselSettingsCubit
                                                                              >()
                                                                              .setViewportFraction,
                                                                          onCarouselEnlargeChanged: sheetContext
                                                                              .read<
                                                                                CarouselSettingsCubit
                                                                              >()
                                                                              .setEnlargeCenter,
                                                                          onOpenMcpFlow: () => _openMcpFlow(
                                                                            controller,
                                                                            sheetContext,
                                                                          ),
                                                                          onOpenLocalWeb: () => _openLocalWeb(
                                                                            controller,
                                                                            sheetContext,
                                                                          ),
                                                                          // onEnterKioskMode:
                                                                          //     _enterKioskMode,
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

    final isOpen =
        controller.status == AnimationStatus.completed ||
        controller.status == AnimationStatus.forward;
    setState(() {
      _settingsSheetVisible = !isOpen;
    });
    controller.toggle();
  }

  void _openMcpFlow(
    FPersistentSheetController controller,
    BuildContext sheetContext,
  ) {
    _closeSettingsSheetOverlay(controller);
    if (!mounted || !sheetContext.mounted) {
      return;
    }
    sheetContext.go(Routes.mcpFlow);
  }

  Future<void> _openLocalWeb(
    FPersistentSheetController controller,
    BuildContext sheetContext,
  ) async {
    _closeSettingsSheetOverlay(controller);
    final hostState = await LocalWebHostService.instance.start(
      preferredPort: 8080,
    );
    final baseUri = hostState.loopbackUri;
    final targetUri = baseUri?.resolve('manager/');
    if (!mounted || !sheetContext.mounted) {
      return;
    }
    if (targetUri == null) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text(hostState.message ?? 'Không thể mở local web.')),
      );
      return;
    }

    final launched = await launchUrl(
      targetUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && sheetContext.mounted) {
      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(content: Text('Không thể mở trình duyệt cho $targetUri')),
      );
    }
  }

  void _closeSettingsSheetOverlay(FPersistentSheetController controller) {
    final isOpen =
        controller.status == AnimationStatus.completed ||
        controller.status == AnimationStatus.forward;
    if (!isOpen) {
      if (_settingsSheetVisible && mounted) {
        setState(() {
          _settingsSheetVisible = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _settingsSheetVisible = false;
      });
    }
    controller.toggle();
  }

  void _setCameraEnabled(bool enabled) {
    if (_cameraEnabled.value == enabled) {
      return;
    }
    _cameraEnabled.value = enabled;
    if (mounted) {
      setState(() {});
    }
  }

  void _setCameraAspectRatio(double aspectRatio) {
    final next = aspectRatio.clamp(0.5, 2.0);
    if ((next - _cameraAspectRatio.value).abs() < 0.001) {
      return;
    }
    _cameraAspectRatio.value = next;
  }

  void _handleFacePresenceChanged(bool hasFace) {
    final changed = _facePresent != hasFace;
    _facePresent = hasFace;
    if (changed && mounted) {
      setState(() {});
    }
    if (!hasFace) {
      _stopFaceCountdown();
      return;
    }
    final state = context.read<HomeCubit>().state;
    if (_shouldAutoConnect(state)) {
      _startFaceCountdown();
    }
  }

  void _checkForUpdates() {
    _updateRequested = true;
    if (mounted) {
      context.go(Routes.update);
    }
    unawaited(context.read<UpdateCubit>().checkForUpdates());
  }

  void _handleUpdateDownloadState(UpdateDownloadState state) {
    if (!mounted || !_updateRequested) {
      return;
    }
    if (state.status == UpdateDownloadStatus.failed) {
      _updateRequested = false;
    } else if (state.status == UpdateDownloadStatus.completed) {
      _updateRequested = false;
    } else if (state.status == UpdateDownloadStatus.updateAvailable) {
      _updateRequested = false;
    } else if (state.status == UpdateDownloadStatus.idle && _updateRequested) {
      _updateRequested = false;
    }
  }

  bool _shouldAutoConnect(HomeState state) =>
      !state.isConnected && !state.isConnecting;

  void _startFaceCountdown() {
    if (_faceConnectTimer != null || !_facePresent) {
      return;
    }
    _faceConnectProgress.value = 0;
    final startedAt = DateTime.now();
    _faceConnectTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_facePresent) {
        _stopFaceCountdown();
        return;
      }
      final state = context.read<HomeCubit>().state;
      if (!_shouldAutoConnect(state)) {
        _stopFaceCountdown();
        return;
      }
      final elapsed = DateTime.now().difference(startedAt);
      final progress =
          (elapsed.inMilliseconds / _faceConnectDelay.inMilliseconds).clamp(
            0.0,
            1.0,
          );
      _faceConnectProgress.value = progress;
      if (progress >= 1.0) {
        _stopFaceCountdown();
        if (_facePresent && _shouldAutoConnect(state)) {
          _handleConnectChat();
        }
      }
    });
  }

  void _stopFaceCountdown() {
    _faceConnectTimer?.cancel();
    _faceConnectTimer = null;
    _faceConnectProgress.value = null;
  }

  String _lastBadgeStatus = '';
  DateTime? _badgeStatusChangedAt;

  Widget _buildConnectionStatusBadge({
    required ChatConnectionStatus status,
    required bool isSpeaking,
    required bool isListening,
    required String? connectionError,
    required bool networkWarning,
    double fontSize = 14,
    double padding = 16,
  }) {
    final now = DateTime.now();
    final timeSinceChange = _badgeStatusChangedAt != null
        ? now.difference(_badgeStatusChangedAt!).inMilliseconds
        : 999999;

    final isConnectionError =
        status == ChatConnectionStatus.error ||
        (connectionError?.isNotEmpty ?? false);
    final nextStatusKey =
        status == ChatConnectionStatus.connecting ||
            status == ChatConnectionStatus.reconnecting
        ? 'connecting'
        : isConnectionError
        ? 'error'
        : status == ChatConnectionStatus.connected
        ? isListening
              ? 'listening'
              : isSpeaking
              ? 'speaking'
              : 'connected'
        : 'disconnected';

    final shouldHoldPrevious =
        nextStatusKey != _lastBadgeStatus &&
        _lastBadgeStatus.isNotEmpty &&
        timeSinceChange < 500;

    if (!shouldHoldPrevious && nextStatusKey != _lastBadgeStatus) {
      _lastBadgeStatus = nextStatusKey;
      _badgeStatusChangedAt = now;
    }

    final statusKey = shouldHoldPrevious ? _lastBadgeStatus : nextStatusKey;

    final visual = switch (statusKey) {
      'listening' => (
        label: 'Đang nghe',
        icon: Icons.hearing_rounded,
        fg: Colors.lightBlue.shade100,
        bg: Colors.lightBlue.withValues(alpha: 0.18),
        border: Colors.lightBlue.withValues(alpha: 0.65),
        loading: false,
      ),
      'speaking' => (
        label: 'Đang nói',
        icon: Icons.graphic_eq_rounded,
        fg: Colors.purple.shade100,
        bg: Colors.purple.withValues(alpha: 0.18),
        border: Colors.purple.withValues(alpha: 0.65),
        loading: false,
      ),
      'connecting' => (
        label: 'Đang kết nối',
        icon: Icons.sync_rounded,
        fg: Colors.orange.shade100,
        bg: Colors.orange.withValues(alpha: 0.18),
        border: Colors.orange.withValues(alpha: 0.65),
        loading: true,
      ),
      'error' => (
        label: networkWarning ? 'Mạng yếu, đang reconnect' : 'Mất kết nối',
        icon: Icons.wifi_off_rounded,
        fg: Colors.red.shade100,
        bg: Colors.red.withValues(alpha: 0.18),
        border: Colors.red.withValues(alpha: 0.65),
        loading: false,
      ),
      'connected' => (
        label: 'Đã kết nối',
        icon: Icons.wifi_rounded,
        fg: Colors.green.shade100,
        bg: Colors.green.withValues(alpha: 0.18),
        border: Colors.green.withValues(alpha: 0.65),
        loading: false,
      ),
      _ => (
        label: 'Chưa kết nối',
        icon: Icons.wifi_tethering_off_rounded,
        fg: Colors.white70,
        bg: Colors.white.withValues(alpha: 0.08),
        border: Colors.white24,
        loading: false,
      ),
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: padding * 0.9,
            vertical: padding * 0.35,
          ),
          decoration: BoxDecoration(
            color: visual.bg,
            borderRadius: BorderRadius.circular(padding * 1.25),
            border: Border.all(color: visual.border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (visual.loading)
                SizedBox(
                  width: fontSize,
                  height: fontSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(visual.fg),
                  ),
                )
              else
                Icon(visual.icon, size: fontSize * 1.05, color: visual.fg),
              SizedBox(width: padding * 0.35),
              Text(
                visual.label,
                style: TextStyle(
                  color: visual.fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (status == ChatConnectionStatus.connected && networkWarning) ...[
          SizedBox(height: padding / 3),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: padding * 0.65,
              vertical: padding * 0.22,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(padding),
              border: Border.all(
                color: Colors.orange.withValues(alpha: 0.65),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.network_check_rounded,
                  size: fontSize * 0.9,
                  color: Colors.orange.shade100,
                ),
                SizedBox(width: padding * 0.25),
                Text(
                  'Mạng yếu',
                  style: TextStyle(
                    color: Colors.orange.shade100,
                    fontSize: fontSize * 0.85,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLandscapeCameraPanel({
    required double cameraSize,
    required double cameraAspectRatio,
    required double fontSize,
    required double padding,
  }) {
    final panelWidth = cameraSize;
    final panelHeight = cameraSize / cameraAspectRatio;
    final panelRadius = (padding * 0.75).clamp(10.0, 14.0).toDouble();
    final cameraEnabled = _cameraEnabled.value;
    final hasFace = _facePresent && cameraEnabled;
    final faceLabel = !cameraEnabled
        ? 'Camera tắt'
        : (hasFace ? 'Đã nhận diện mặt' : 'Chưa nhận diện mặt');
    final faceColor = !cameraEnabled
        ? Colors.white70
        : (hasFace ? Colors.green.shade100 : Colors.orange.shade100);
    final faceIcon = !cameraEnabled
        ? Icons.videocam_off_rounded
        : (hasFace ? Icons.verified_user_rounded : Icons.person_search_rounded);

    return Positioned(
      top: padding * 0.45,
      right: padding * 0.45,
      child: SizedBox(
        width: panelWidth,
        height: panelHeight,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.3),
                Colors.black.withValues(alpha: 0.14),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.28),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(panelRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(panelRadius - 1),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 180;
                final statusLabel = compact
                    ? (!cameraEnabled
                          ? 'Tắt'
                          : (hasFace ? 'Có mặt' : 'Chưa thấy'))
                    : faceLabel;
                return Stack(
                  children: [
                    HomeCameraOverlay(
                      areaSize: Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      ),
                      enabled: cameraEnabled,
                      onEnabledChanged: _setCameraEnabled,
                      onFacePresenceChanged: _handleFacePresenceChanged,
                      detectFacesEnabled: _detectFacesEnabled.value,
                      aspectRatio: cameraAspectRatio,
                      faceLandmarksEnabled: false,
                      faceMeshEnabled: false,
                      eyeTrackingEnabled: false,
                      edgePadding: 0,
                      decorateContainer: false,
                      borderRadius: panelRadius - 1,
                    ),
                    Positioned(
                      top: padding * 0.25,
                      left: padding * 0.25,
                      right: padding * 0.25,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: padding * 0.45,
                          vertical: padding * 0.18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(padding),
                          border: Border.all(
                            color: faceColor.withValues(alpha: 0.72),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              faceIcon,
                              size: fontSize * 0.85,
                              color: faceColor,
                            ),
                            SizedBox(width: padding * 0.2),
                            Expanded(
                              child: Text(
                                statusLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: faceColor,
                                  fontSize: compact
                                      ? fontSize * 0.56
                                      : fontSize * 0.62,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeConnectionButton({
    required ChatConnectionStatus status,
    required double fontSize,
    required double padding,
    required bool inFlight,
  }) {
    final isConnecting =
        status == ChatConnectionStatus.connecting ||
        status == ChatConnectionStatus.reconnecting ||
        inFlight;
    final isConnected = status == ChatConnectionStatus.connected;
    final label = isConnected ? 'Ngắt kết nối' : 'Kết nối';
    final background = isConnected
        ? Colors.red.withValues(alpha: 0.18)
        : Colors.green.withValues(alpha: 0.18);
    final border = isConnected
        ? Colors.red.withValues(alpha: 0.65)
        : Colors.green.withValues(alpha: 0.65);
    final foreground = isConnected
        ? Colors.red.shade100
        : Colors.green.shade100;

    return GestureDetector(
      onTap: isConnecting
          ? null
          : () {
              unawaited(_toggleLandscapeWsConnection(status));
            },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: padding * 0.7,
          vertical: padding * 0.3,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(padding),
          border: Border.all(color: border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isConnecting)
              SizedBox(
                width: fontSize,
                height: fontSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.orangeAccent,
                  ),
                ),
              )
            else
              Icon(
                isConnected ? Icons.wifi_off_rounded : Icons.wifi_rounded,
                size: fontSize * 1.1,
                color: foreground,
              ),
            SizedBox(width: padding * 0.35),
            Text(
              isConnecting ? 'Đang kết nối' : label,
              style: TextStyle(
                color: isConnecting ? Colors.orangeAccent : foreground,
                fontSize: fontSize * 0.9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatMessagesList(
    List<ChatMessage> messages,
    double fontSize,
    double padding,
  ) {
    if (messages.isEmpty) {
      return const SizedBox.shrink();
    }

    final latestMessage = messages.last;
    final isUser = latestMessage.isUser;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(padding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isUser ? Icons.person : Icons.smart_toy,
              color: isUser ? Colors.blue : Colors.purple,
              size: fontSize * 1.2,
            ),
            SizedBox(width: padding / 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isUser ? 'Bạn' : 'Agent',
                    style: TextStyle(
                      color: isUser ? Colors.blue : Colors.purple,
                      fontSize: fontSize * 0.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    latestMessage.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: fontSize),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmotionSelector(
    String? currentEmotion,
    double fontSize,
    double padding,
  ) {
    final emotion = currentEmotion ?? 'neutral';
    final emojiSize = fontSize * 30;

    return SizedBox(
      width: emojiSize,
      height: emojiSize,
      child: Image.asset(
        'assets/emojis/$emotion.gif',
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            Icons.emoji_emotions,
            color: Colors.white54,
            size: emojiSize,
          );
        },
      ),
    );
  }
}
