import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:audio_router/audio_router.dart';

import '../../core/config/app_config.dart';
import '../../core/permissions/permission_type.dart';
import '../../core/system/ota/model/ota_result.dart';
import '../../core/theme/forui/theme_tokens.dart';
import '../../features/chat/application/state/chat_cubit.dart';
import '../../features/chat/application/state/chat_state.dart';
import '../../features/chat/domain/entities/chat_message.dart';
import '../../features/home/application/state/home_cubit.dart';
import '../../features/home/application/state/home_state.dart';
import '../../features/home/domain/entities/home_wifi_network.dart';
import '../../theme/brand_colors.dart';
import '../../theme/theme_extensions.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../system/permissions/permission_state.dart';
import 'permission_sheet_content.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final ChatCubit _chatCubit;
  final AudioPlayer _chimePlayer = AudioPlayer();
  late final Uint8List _chimeBytes = _buildChimeWavBytes();
  DateTime _lastChimeAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _wasSpeaking = false;
  String _wifiPassword = '';
  bool _permissionSheetOpen = false;
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    _chatCubit = context.read<ChatCubit>();
    context.read<HomeCubit>().initialize();
    if (AppConfig.permissionsEnabled) {
      _schedulePermissionPrompt();
    }
  }

  @override
  void dispose() {
    _chimePlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
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

  Future<void> _handleVolumeChanged(double value) async {
    await context.read<HomeCubit>().setVolume(value);
  }

  Widget _buildFullHome(BuildContext context) {
    _scheduleHeaderMeasure();
    return FScaffold(
      child: SafeArea(
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
                  child:
                      BlocSelector<
                        HomeCubit,
                        HomeState,
                        ({
                          DateTime now,
                          int? batteryLevel,
                          BatteryState? batteryState,
                          List<ConnectivityResult>? connectivity,
                          double? volume,
                          AudioDevice? audioDevice,
                          String? wifiName,
                          String? carrierName,
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
                        ),
                        builder: (context, data) {
                          return _HomeHeader(
                            now: data.now,
                            batteryLevel: data.batteryLevel,
                            batteryState: data.batteryState,
                            connectivity: data.connectivity,
                            volume: data.volume,
                            audioDevice: data.audioDevice,
                            wifiName: data.wifiName,
                            carrierName: data.carrierName,
                            onWifiTap: _refreshWifiNetworks,
                            onWifiSettings: _openWifiSettings,
                            onWifiSelect: _openWifiPasswordSheet,
                            onVolumeChanged: _handleVolumeChanged,
                          );
                        },
                      ),
                ),
              ),
              SizedBox(height: _headerSpacing()),
              BlocSelector<ChatCubit, ChatState, String?>(
                selector: (state) => state.currentEmotion,
                builder: (context, emotion) {
                  final palette = _EmotionPalette.resolve(context, emotion);
                  return Expanded(child: _HomeContent(palette: palette));
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
                builder: (context, data) {
                  return _HomeFooter(
                    activation: data.activation,
                    awaitingActivation: data.awaitingActivation,
                    activationProgress: data.activationProgress,
                    onConnect: _handleConnectChat,
                    onDisconnect: _handleDisconnectChat,
                    isConnecting: data.isConnecting,
                    isConnected: data.isConnected,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
    final spacing = _headerHeight * 0.15;
    return spacing.clamp(8.0, 24.0);
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

            return _WifiPasswordSheet(
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

  static String _normalizeTranscript(String text) {
    return text.replaceAll(RegExp(r'\n{2,}'), '\n').trimRight();
  }

  static List<TextSpan> _highlightNumbers(
    String text,
    TextStyle baseStyle,
    TextStyle numberStyle,
  ) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\d+');
    var start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: numberStyle,
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return spans;
  }
}

class _AnimatedAgentTranscript extends StatefulWidget {
  const _AnimatedAgentTranscript({
    required this.text,
    required this.readStyle,
    required this.unreadStyle,
    required this.numberReadStyle,
    required this.numberUnreadStyle,
    this.durationHintMs,
  });

  final String text;
  final TextStyle readStyle;
  final TextStyle unreadStyle;
  final TextStyle numberReadStyle;
  final TextStyle numberUnreadStyle;
  final int? durationHintMs;

  @override
  State<_AnimatedAgentTranscript> createState() =>
      _AnimatedAgentTranscriptState();
}

class _AnimatedAgentTranscriptState extends State<_AnimatedAgentTranscript>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  List<_TranscriptToken> _tokens = const [];
  int _wordCount = 0;
  int _readWords = 0;
  Duration _perWordDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _resetAnimation();
  }

  @override
  void didUpdateWidget(_AnimatedAgentTranscript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.durationHintMs != widget.durationHintMs) {
      _resetAnimation();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tokens.isEmpty) {
      return const SizedBox.shrink();
    }
    final spans = _buildWordSpans(_tokens, _readWords);
    return Text.rich(TextSpan(children: spans), textAlign: TextAlign.left);
  }

  void _resetAnimation() {
    _controller?.dispose();
    _tokens = _tokenize(widget.text);
    _wordCount = _tokens.where((token) => token.isWord).length;
    _readWords = 0;
    _perWordDuration = _computePerWordDuration();

    if (_wordCount == 0) {
      setState(() {});
      return;
    }

    _controller = AnimationController(vsync: this, duration: _perWordDuration)
      ..addStatusListener((status) {
        if (status != AnimationStatus.completed) {
          return;
        }
        if (!mounted) {
          return;
        }
        if (_readWords >= _wordCount) {
          return;
        }
        setState(() {
          _readWords += 1;
        });
        if (_readWords < _wordCount) {
          _controller?.forward(from: 0);
        }
      });
    _controller?.forward();
    setState(() {});
  }

  Duration _computePerWordDuration() {
    if (_wordCount <= 0) {
      return Duration.zero;
    }
    return const Duration(milliseconds: 20);
  }

  List<TextSpan> _buildWordSpans(List<_TranscriptToken> tokens, int readWords) {
    final spans = <TextSpan>[];
    var wordIndex = 0;
    for (final token in tokens) {
      if (!token.isWord) {
        final isRead = wordIndex <= readWords;
        spans.add(
          TextSpan(
            text: token.text,
            style: isRead ? widget.readStyle : widget.unreadStyle,
          ),
        );
        continue;
      }
      final isRead = wordIndex < readWords;
      wordIndex += 1;
      spans.addAll(_highlightNumbersForToken(token.text, isRead));
    }
    return spans;
  }

  List<TextSpan> _highlightNumbersForToken(String text, bool read) {
    final baseStyle = read ? widget.readStyle : widget.unreadStyle;
    final numberStyle = read
        ? widget.numberReadStyle
        : widget.numberUnreadStyle;
    final spans = <TextSpan>[];
    final regex = RegExp(r'\d+');
    var start = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: numberStyle,
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: baseStyle));
    }
    return spans;
  }

  List<_TranscriptToken> _tokenize(String text) {
    if (text.isEmpty) {
      return const [];
    }
    final tokens = <_TranscriptToken>[];
    final regex = RegExp(r'\s+|\S+');
    for (final match in regex.allMatches(text)) {
      final token = match.group(0);
      if (token == null || token.isEmpty) {
        continue;
      }
      final isWord = token.trim().isNotEmpty;
      tokens.add(_TranscriptToken(token, isWord));
    }
    return tokens;
  }
}

class _TranscriptToken {
  const _TranscriptToken(this.text, this.isWord);

  final String text;
  final bool isWord;
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.now,
    required this.batteryLevel,
    required this.batteryState,
    required this.connectivity,
    required this.volume,
    required this.audioDevice,
    required this.wifiName,
    required this.carrierName,
    this.onWifiTap,
    this.onWifiSettings,
    this.onWifiSelect,
    this.onVolumeChanged,
  });

  final DateTime now;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final List<ConnectivityResult>? connectivity;
  final double? volume;
  final AudioDevice? audioDevice;
  final String? wifiName;
  final String? carrierName;
  final VoidCallback? onWifiTap;
  final VoidCallback? onWifiSettings;
  final ValueChanged<HomeWifiNetwork>? onWifiSelect;
  final ValueChanged<double>? onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    final dateText = '${_two(now.day)}/${_two(now.month)}/${now.year}';
    final timeText = '${_two(now.hour)}:${_two(now.minute)}';
    final networkDisplay = _networkDisplay(connectivity, wifiName, carrierName);
    final isOffline = _isOffline(connectivity);
    final headerTextColor = context.theme.brand.headerForeground;
    final wifiTextColor = isOffline
        ? context.theme.colors.destructive
        : headerTextColor;
    final wifiEnabled =
        connectivity?.contains(ConnectivityResult.wifi) ?? false;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: ThemeTokens.spaceSm),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  dateText,
                  style: context.theme.typography.base.copyWith(
                    color: headerTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Text(
                  timeText,
                  style: context.theme.typography.base.copyWith(
                    color: headerTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FPopover(
                      control: FPopoverControl.managed(),
                      popoverAnchor: Alignment.bottomRight,
                      childAnchor: Alignment.topRight,
                      spacing: const FPortalSpacing(6),
                      popoverBuilder: (context, controller) =>
                          _AudioPopoverContent(
                            volume: volume,
                            onChanged: onVolumeChanged,
                          ),
                      builder: (_, controller, _) => GestureDetector(
                        onTap: controller.toggle,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: ThemeTokens.spaceXs,
                            vertical: 2,
                          ),
                          child: _AudioStatusValue(
                            volume: volume,
                            audioDevice: audioDevice,
                            color: headerTextColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: ThemeTokens.spaceSm),
                    BlocSelector<
                      HomeCubit,
                      HomeState,
                      ({
                        List<HomeWifiNetwork> networks,
                        bool wifiLoading,
                        String? wifiError,
                      })
                    >(
                      selector: (state) => (
                        networks: state.wifiNetworks,
                        wifiLoading: state.wifiLoading,
                        wifiError: state.wifiError,
                      ),
                      builder: (context, wifiData) {
                        return FPopover(
                          control: FPopoverControl.managed(
                            onChange: (shown) {
                              if (shown) {
                                onWifiTap?.call();
                              }
                            },
                          ),
                          popoverAnchor: Alignment.bottomRight,
                          childAnchor: Alignment.topRight,
                          spacing: const FPortalSpacing(6),
                          popoverBuilder: (context, controller) =>
                              _WifiPopoverContent(
                                isLoading: wifiData.wifiLoading,
                                errorMessage: wifiData.wifiError,
                                networks: wifiData.networks,
                                onRefresh: onWifiTap,
                                onSelect: (network) {
                                  controller.hide();
                                  onWifiSelect?.call(network);
                                },
                              ),
                          builder: (_, controller, _) => GestureDetector(
                            onTap: () {
                              if (!wifiEnabled) {
                                showFToast(
                                  context: context,
                                  alignment: FToastAlignment.topRight,
                                  icon: const Icon(FIcons.wifiOff),
                                  title: const Text('Wi‑Fi đang tắt'),
                                  description: const Text(
                                    'Bật Wi‑Fi để xem danh sách.',
                                  ),
                                  suffixBuilder: (context, entry) => FButton(
                                    mainAxisSize: MainAxisSize.min,
                                    onPress: () {
                                      entry.dismiss();
                                      onWifiSettings?.call();
                                    },
                                    child: const Text('Mở cài đặt'),
                                  ),
                                );
                                return;
                              }
                              controller.toggle();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ThemeTokens.spaceXs,
                                vertical: 2,
                              ),
                              child: _StatusIconValue(
                                icon: _wifiIcon(connectivity, wifiName),
                                value: networkDisplay,
                                color: wifiTextColor,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: ThemeTokens.spaceSm),
                    _StatusIconValue(
                      icon: _batteryIcon(batteryLevel, batteryState),
                      value: _batteryText(batteryLevel, batteryState),
                      color: headerTextColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static String _batteryText(int? level, BatteryState? state) {
    final percent = level == null ? '--' : '$level%';
    return percent;
  }

  static IconData _batteryIcon(int? level, BatteryState? state) {
    if (state == BatteryState.charging) {
      return FIcons.batteryCharging;
    }
    if (level == null) {
      return FIcons.battery;
    }
    if (level < 10) {
      return FIcons.batteryLow;
    }
    if (level < 50) {
      return FIcons.batteryLow;
    }
    if (level < 85) {
      return FIcons.batteryMedium;
    }
    return FIcons.batteryFull;
  }

  static String _volumeText(double? volume) {
    if (volume == null) {
      return '--%';
    }
    return '${(volume * 100).round()}%';
  }

  static IconData _audioIcon(double? volume) {
    if (volume == null) {
      return FIcons.volume;
    }
    if (volume <= 0.01) {
      return FIcons.volumeOff;
    }
    if (volume < 0.34) {
      return FIcons.volume;
    }
    if (volume < 0.67) {
      return FIcons.volume1;
    }
    return FIcons.volume2;
  }

  static IconData? _routeIcon(AudioDevice? device) {
    if (device == null) {
      return null;
    }
    switch (device.type) {
      case AudioSourceType.bluetooth:
        return FIcons.bluetoothSearching;
      case AudioSourceType.builtinSpeaker:
        return FIcons.speaker;
      default:
        return null;
    }
  }

  static String _networkDisplay(
    List<ConnectivityResult>? results,
    String? wifiName,
    String? carrierName,
  ) {
    if (results == null || results.isEmpty) {
      return '--';
    }
    if (results.contains(ConnectivityResult.wifi)) {
      final name = _cleanWifiName(wifiName);
      return name ?? 'Wi‑Fi';
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return carrierName ?? 'Mobile';
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet';
    }
    return 'Offline';
  }

  static bool _isOffline(List<ConnectivityResult>? results) {
    if (results == null || results.isEmpty) {
      return true;
    }
    if (results.contains(ConnectivityResult.none)) {
      return true;
    }
    return false;
  }

  static String? _cleanWifiName(String? name) {
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

  static IconData _wifiIcon(
    List<ConnectivityResult>? results,
    String? wifiName,
  ) {
    if (results == null || results.isEmpty) {
      return FIcons.wifiOff;
    }
    if (results.contains(ConnectivityResult.wifi)) {
      final hasName = _cleanWifiName(wifiName) != null;
      return hasName ? FIcons.wifiHigh : FIcons.wifiLow;
    }
    if (results.contains(ConnectivityResult.mobile)) {
      return FIcons.cardSim;
    }
    if (results.contains(ConnectivityResult.ethernet)) {
      return FIcons.wifiHigh;
    }
    return FIcons.wifiOff;
  }
}

class _EmotionPalette {
  const _EmotionPalette({
    required this.surface,
    required this.accent,
    required this.accentForeground,
  });

  final Color surface;
  final Color accent;
  final Color accentForeground;

  static _EmotionPalette resolve(BuildContext context, String? emotion) {
    final brand = context.theme.brand;
    final normalized = emotion?.toLowerCase().trim();

    final tone = _toneFor(normalized, brand);

    return _EmotionPalette(
      surface: brand.homeSurface,
      accent: tone.background,
      accentForeground: tone.foreground,
    );
  }

  Color controlBackground(BuildContext context) {
    return surface;
  }

  Color controlBorder(BuildContext context) {
    return context.theme.brand.emotionBorder;
  }

  Color controlForeground(BuildContext context) {
    return context.theme.brand.headerForeground;
  }

  static _EmotionTone _toneFor(String? emotion, BrandColors brand) {
    final tone = brand.emotionTones[emotion];
    if (tone != null) {
      return _EmotionTone(tone.background.value, tone.foreground.value);
    }
    return _EmotionTone(brand.homeAccent.value, brand.accentForeground.value);
  }
}

class _EmotionTone {
  _EmotionTone(int background, int foreground)
    : background = Color(background),
      foreground = Color(foreground);

  final Color background;
  final Color foreground;
}

class _HomeContent extends StatelessWidget {
  const _HomeContent({required this.palette});

  final _EmotionPalette palette;
  static const double _audioActiveThreshold = 0.02;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        color: palette.surface,
        child: Column(
          children: [
            const SizedBox(height: ThemeTokens.spaceSm),
            _ConnectionStatusBanner(
              palette: palette,
              audioThreshold: _audioActiveThreshold,
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            Expanded(
              child: Center(
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: palette.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: CustomPaint(
                        painter: _SmileFacePainter(
                          color: palette.accentForeground,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusBanner extends StatefulWidget {
  const _ConnectionStatusBanner({
    required this.palette,
    required this.audioThreshold,
  });

  final _EmotionPalette palette;
  final double audioThreshold;

  @override
  State<_ConnectionStatusBanner> createState() =>
      _ConnectionStatusBannerState();
}

class _ConnectionStatusBannerState extends State<_ConnectionStatusBanner> {
  bool? _lastWasSpeaking;

  FBadgeStyle _buildBadgeStyle(
    BuildContext context, {
    required Color background,
    required Color foreground,
    Color? border,
  }) {
    final typography = context.theme.typography;
    final borderRadius = FBadgeStyles.defaultRadius;
    final decoration = BoxDecoration(
      color: background,
      borderRadius: borderRadius,
      border: border == null
          ? null
          : Border.all(color: border, width: context.theme.style.borderWidth),
    );
    return FBadgeStyle(
      decoration: decoration,
      contentStyle: FBadgeContentStyle(
        labelTextStyle: typography.sm.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      ChatCubit,
      ChatState,
      ({
        ChatConnectionStatus status,
        bool isSpeaking,
        double outgoing,
        String? error,
        bool networkWarning,
      })
    >(
      selector: (state) => (
        status: state.status,
        isSpeaking: state.isSpeaking,
        outgoing: state.outgoingLevel,
        error: state.connectionError,
        networkWarning: state.networkWarning,
      ),
      builder: (context, snapshot) {
        final colors = context.theme.colors;
        final palette = widget.palette;
        final isListening =
            !snapshot.isSpeaking && snapshot.outgoing > widget.audioThreshold;
        final status = snapshot.status;
        final networkWarning = snapshot.networkWarning;

        String label;
        FBadgeStyle badgeStyle;

        if (status == ChatConnectionStatus.connecting ||
            status == ChatConnectionStatus.reconnecting) {
          label = 'Đang kết nối';
          badgeStyle = _buildBadgeStyle(
            context,
            background: colors.primary,
            foreground: colors.primaryForeground,
          );
        } else if (status == ChatConnectionStatus.error ||
            snapshot.error != null) {
          label = networkWarning ? 'Mất kết nối do mạng yếu' : 'Mất kết nối';
          badgeStyle = _buildBadgeStyle(
            context,
            background: colors.destructive,
            foreground: colors.destructiveForeground,
          );
        } else if (status == ChatConnectionStatus.connected) {
          if (snapshot.isSpeaking) {
            _lastWasSpeaking = true;
            label = 'Đang nói';
            badgeStyle = _buildBadgeStyle(
              context,
              background: palette.accent,
              foreground: palette.accentForeground,
            );
          } else if (isListening) {
            _lastWasSpeaking = false;
            label = 'Đang nghe';
            badgeStyle = _buildBadgeStyle(
              context,
              background: colors.secondary,
              foreground: colors.secondaryForeground,
            );
          } else {
            final wasSpeaking = _lastWasSpeaking ?? false;
            label = wasSpeaking ? 'Đang nói' : 'Đang nghe';
            badgeStyle = _buildBadgeStyle(
              context,
              background: wasSpeaking ? palette.accent : colors.secondary,
              foreground: wasSpeaking
                  ? palette.accentForeground
                  : colors.secondaryForeground,
            );
          }
        } else {
          label = 'Chưa kết nối';
          badgeStyle = _buildBadgeStyle(
            context,
            background: colors.muted,
            foreground: colors.mutedForeground,
            border: colors.border,
          );
        }

        final warningBadge =
            status == ChatConnectionStatus.connected && networkWarning
            ? FBadge(
                style: _buildBadgeStyle(
                  context,
                  background: colors.primary,
                  foreground: colors.primaryForeground,
                ),
                child: const Text('Mạng yếu'),
              )
            : null;

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FBadge(style: badgeStyle, child: Text(label)),
              if (warningBadge != null) ...[
                const SizedBox(height: 6),
                warningBadge,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter({
    required this.activation,
    required this.awaitingActivation,
    required this.activationProgress,
    required this.onConnect,
    required this.onDisconnect,
    required this.isConnecting,
    required this.isConnected,
  });

  final Activation? activation;
  final bool awaitingActivation;
  final double activationProgress;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final bool isConnecting;
  final bool isConnected;

  static const double _audioActiveThreshold = 0.02;

  static const List<String> _emotionOptions = [
    'neutral',
    'happy',
    'laughing',
    'funny',
    'sad',
    'angry',
    'crying',
    'loving',
    'embarrassed',
    'surprised',
    'shocked',
    'thinking',
    'winking',
    'cool',
    'relaxed',
    'delicious',
    'kissy',
    'confident',
    'sleepy',
    'silly',
    'confused',
  ];

  @override
  Widget build(BuildContext context) {
    final headerBackground = context.theme.brand.headerBackground;
    final headerForeground = context.theme.brand.headerForeground;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.spaceMd,
        vertical: ThemeTokens.spaceSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BlocSelector<ChatCubit, ChatState, String?>(
            selector: (state) => state.currentEmotion,
            builder: (context, emotion) {
              final selectedIndex = _emotionIndex(emotion);
              final palette = _EmotionPalette.resolve(context, emotion);
              return _EmotionPicker(
                options: _emotionOptions,
                selectedIndex: selectedIndex,
                palette: palette,
              );
            },
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          if (activation != null) ...[
            SizedBox(
              width: double.infinity,
              child: FTextField(
                label: const Text('Activation'),
                readOnly: true,
                control: FTextFieldControl.lifted(
                  value: TextEditingValue(
                    text: activation?.code ?? '',
                    selection: TextSelection.collapsed(
                      offset: (activation?.code ?? '').length,
                    ),
                  ),
                  onChange: (_) {},
                ),
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            if (awaitingActivation)
              FDeterminateProgress(
                value: activationProgress,
                semanticsLabel: 'Activation progress',
              ),
          ] else ...[
            BlocSelector<
              ChatCubit,
              ChatState,
              ({ChatMessage? message, int? ttsDurationMs, String? ttsText})
            >(
              selector: (state) => (
                message: state.messages.isNotEmpty ? state.messages.last : null,
                ttsDurationMs: state.lastTtsDurationMs,
                ttsText: state.lastTtsText,
              ),
              builder: (context, snapshot) {
                final lastMessage = snapshot.message;
                if (lastMessage == null) {
                  return Text(
                    'Transcript / lời thoại',
                    textAlign: TextAlign.left,
                    style: context.theme.typography.xl.copyWith(
                      color: context.theme.colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  );
                }
                final rawText = lastMessage.text;
                final text = _HomePageState._normalizeTranscript(rawText);
                final prefix = lastMessage.isUser ? 'USER: ' : 'AGENT: ';
                final readStyle = context.theme.typography.xl.copyWith(
                  color: context.theme.colors.foreground,
                  fontWeight: FontWeight.w600,
                );
                final prefixStyle = readStyle.copyWith(
                  fontWeight: FontWeight.w700,
                );
                final unreadStyle = context.theme.typography.xl.copyWith(
                  color: context.theme.colors.mutedForeground,
                  fontWeight: FontWeight.w600,
                );
                final numberReadStyle = TextStyle(
                  color: context.theme.colors.destructive,
                  fontWeight: FontWeight.w700,
                );
                final numberUnreadStyle = TextStyle(
                  color: context.theme.colors.destructive.withAlpha(140),
                  fontWeight: FontWeight.w700,
                );
                final durationHintMs =
                    !lastMessage.isUser &&
                        snapshot.ttsText?.trim() == rawText.trim()
                    ? snapshot.ttsDurationMs
                    : null;
                return ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: lastMessage.isUser
                        ? Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(text: prefix, style: prefixStyle),
                                ..._HomePageState._highlightNumbers(
                                  text,
                                  readStyle,
                                  numberReadStyle,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.left,
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(prefix, style: prefixStyle),
                              Expanded(
                                child: _AnimatedAgentTranscript(
                                  text: text,
                                  readStyle: readStyle,
                                  unreadStyle: unreadStyle,
                                  numberReadStyle: numberReadStyle,
                                  numberUnreadStyle: numberUnreadStyle,
                                  durationHintMs: durationHintMs,
                                ),
                              ),
                            ],
                          ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: ThemeTokens.spaceSm),
          BlocSelector<
            ChatCubit,
            ChatState,
            ({double incoming, double outgoing, bool isSpeaking})
          >(
            selector: (state) => (
              incoming: state.incomingLevel,
              outgoing: state.outgoingLevel,
              isSpeaking: state.isSpeaking,
            ),
            builder: (context, snapshot) {
              final serverLevel = snapshot.incoming;
              final userLevel = snapshot.outgoing;
              final isServerSpeaking = snapshot.isSpeaking;
              final isUserSpeaking =
                  !isServerSpeaking && userLevel > _audioActiveThreshold;
              final color = isServerSpeaking
                  ? context.theme.colors.destructive
                  : isUserSpeaking
                  ? context.theme.colors.primary
                  : context.theme.colors.mutedForeground;
              final level = isServerSpeaking
                  ? serverLevel
                  : (isUserSpeaking ? userLevel : 0.0);
              return RepaintBoundary(
                child: _AudioWaveIndicator(level: level, color: color),
              );
            },
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          Row(
            children: [
              const Spacer(),
              Row(
                children: [
                  FButton(
                    onPress: isConnected ? onDisconnect : null,
                    style: FButtonStyle.secondary(
                      (style) => style.copyWith(
                        contentStyle: (content) => content.copyWith(
                          textStyle: content.textStyle.map(
                            (style) =>
                                style.copyWith(fontWeight: FontWeight.w700),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    mainAxisSize: MainAxisSize.min,
                    child: const Text('Ngắt kết nối'),
                  ),
                  const SizedBox(width: ThemeTokens.spaceSm),
                  FButton(
                    onPress: isConnected || isConnecting ? null : onConnect,
                    style: FButtonStyle.primary(
                      (style) =>
                          FButtonStyle.inherit(
                            colors: context.theme.colors,
                            typography: context.theme.typography,
                            style: context.theme.style,
                            color: headerBackground,
                            foregroundColor: headerForeground,
                          ).copyWith(
                            contentStyle: (content) => content.copyWith(
                              textStyle: content.textStyle.map(
                                (style) =>
                                    style.copyWith(fontWeight: FontWeight.w700),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                            ),
                          ),
                    ),
                    mainAxisSize: MainAxisSize.min,
                    child: Text(
                      isConnected
                          ? 'Đã kết nối'
                          : isConnecting
                          ? 'Đang kết nối'
                          : 'Kết nối',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _emotionIndex(String? emotion) {
    if (emotion == null || emotion.isEmpty) {
      return 0;
    }
    final normalized = emotion.toLowerCase().trim();
    final index = _emotionOptions.indexOf(normalized);
    if (index == -1) {
      return 0;
    }
    return index;
  }
}

class _AudioWaveIndicator extends StatefulWidget {
  const _AudioWaveIndicator({required this.level, required this.color});

  final double level;
  final Color color;

  static const _heights = [
    8.0,
    10.0,
    12.0,
    14.0,
    16.0,
    18.0,
    20.0,
    22.0,
    24.0,
    26.0,
    28.0,
    30.0,
    32.0,
    34.0,
    36.0,
    38.0,
    40.0,
    42.0,
    44.0,
    46.0,
    48.0,
    46.0,
    44.0,
    42.0,
    40.0,
    38.0,
    36.0,
    34.0,
    32.0,
    30.0,
    28.0,
    26.0,
    24.0,
    22.0,
    20.0,
    18.0,
    16.0,
    14.0,
    12.0,
    10.0,
    8.0,
  ];

  @override
  State<_AudioWaveIndicator> createState() => _AudioWaveIndicatorState();
}

class _AudioWaveIndicatorState extends State<_AudioWaveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<double> _barSeeds = _buildSeeds();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
      value: 0,
    );
  }

  @override
  void didUpdateWidget(covariant _AudioWaveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      _animateToLevel();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateToLevel() {
    final target = widget.level.clamp(0.0, 1.0);
    if (target == 0) {
      _controller.stop();
      _controller.value = 0;
      return;
    }
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final level = _controller.value;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _AudioWaveIndicator._heights.length; i++) ...[
                Container(
                  width: 5,
                  height: _scaledHeight(
                    _AudioWaveIndicator._heights[i],
                    i,
                    level,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                if (i != _AudioWaveIndicator._heights.length - 1)
                  const SizedBox(width: 1),
              ],
            ],
          );
        },
      ),
    );
  }

  double _scaledHeight(double base, int index, double level) {
    final seed = _barSeeds[index % _barSeeds.length];
    final intensity = level.clamp(0.0, 1.0);
    final boosted = math.pow(intensity, 0.5).toDouble();
    final scaled = base * (0.2 + 1.2 * boosted * seed);
    return scaled.clamp(4.0, base * 1.4);
  }

  List<double> _buildSeeds() {
    final seeds = <double>[];
    for (var i = 0; i < _AudioWaveIndicator._heights.length; i++) {
      final v = math.sin(i * 12.9898) * 43758.5453;
      final seed = v - v.floorToDouble();
      seeds.add(0.6 + 0.4 * seed);
    }
    return seeds;
  }
}

class _StatusIconValue extends StatelessWidget {
  const _StatusIconValue({required this.icon, required this.value, this.color});

  final IconData icon;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final colors = context.theme.colors;
    final effectiveColor = color ?? colors.foreground;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: typography.base.copyWith(
            color: effectiveColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: ThemeTokens.spaceXs),
        Icon(icon, size: 18, color: effectiveColor),
      ],
    );

    return content;
  }
}

class _AudioStatusValue extends StatelessWidget {
  const _AudioStatusValue({
    required this.volume,
    required this.audioDevice,
    this.color,
  });

  final double? volume;
  final AudioDevice? audioDevice;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final colors = context.theme.colors;
    final effectiveColor = color ?? colors.foreground;
    final volumeValue = volume;
    final value = _HomeHeader._volumeText(volumeValue);
    final isMax = (volumeValue ?? 0) >= 0.99;
    final routeIcon = isMax ? _HomeHeader._routeIcon(audioDevice) : null;
    final icon = routeIcon ?? _HomeHeader._audioIcon(volumeValue);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: typography.base.copyWith(
            color: effectiveColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: ThemeTokens.spaceXs),
        Icon(icon, size: 18, color: effectiveColor),
      ],
    );
  }
}

class _AudioPopoverContent extends StatelessWidget {
  const _AudioPopoverContent({required this.volume, this.onChanged});

  final double? volume;
  final ValueChanged<double>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final typography = context.theme.typography;
    final value = (volume ?? 0.35).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.foreground.withAlpha(26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'Âm lượng',
                    style: typography.base.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colors.foreground,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${(value * 100).round()}%',
                    style: typography.sm.copyWith(
                      color: colors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ThemeTokens.spaceSm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = (constraints.maxWidth - 24).clamp(
                    160.0,
                    360.0,
                  );
                  return FSlider(
                    control: FSliderControl.managedContinuous(
                      initial: FSliderValue(max: value),
                      onChange: (next) => onChanged?.call(next.max),
                    ),
                    layout: FLayout.ltr,
                    trackMainAxisExtent: trackWidth,
                    marks: const [
                      FSliderMark(value: 0, label: Text('0%')),
                      FSliderMark(value: 0.25, tick: false),
                      FSliderMark(value: 0.5),
                      FSliderMark(value: 0.75, tick: false),
                      FSliderMark(value: 1, label: Text('100%')),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _wifiSignalIcon(int level) {
  if (level < -70) {
    return FIcons.wifiLow;
  }
  return FIcons.wifiHigh;
}

class _WifiPopoverContent extends StatefulWidget {
  const _WifiPopoverContent({
    required this.networks,
    required this.isLoading,
    required this.errorMessage,
    required this.onRefresh,
    required this.onSelect,
  });

  final List<HomeWifiNetwork> networks;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRefresh;
  final ValueChanged<HomeWifiNetwork> onSelect;

  @override
  State<_WifiPopoverContent> createState() => _WifiPopoverContentState();
}

class _WifiPopoverContentState extends State<_WifiPopoverContent> {
  HomeWifiNetwork? _selected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: context.theme.colors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.theme.colors.border),
          boxShadow: [
            BoxShadow(
              color: context.theme.colors.foreground.withAlpha(26),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    _selected == null ? 'Wi‑Fi' : 'Chi tiết Wi‑Fi',
                    style: context.theme.typography.base.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  const Spacer(),
                  if (_selected == null)
                    IconButton(
                      onPressed: widget.onRefresh,
                      icon: Icon(
                        FIcons.refreshCw,
                        size: 16,
                        color: context.theme.colors.mutedForeground,
                      ),
                    )
                  else
                    IconButton(
                      onPressed: null,
                      icon: Icon(
                        FIcons.refreshCw,
                        size: 16,
                        color: Colors.transparent,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: ThemeTokens.spaceXs),
              Expanded(
                child: _selected == null
                    ? _buildList(context)
                    : _buildDetails(context, _selected!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: FCircularProgress());
    }
    if (widget.errorMessage != null) {
      return Center(
        child: Text(
          widget.errorMessage!,
          style: context.theme.typography.sm.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
      );
    }
    if (widget.networks.isEmpty) {
      return Center(
        child: Text(
          'Không tìm thấy Wi‑Fi.',
          style: context.theme.typography.sm.copyWith(
            color: context.theme.colors.mutedForeground,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: widget.networks.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final network = widget.networks[index];
        return InkWell(
          onTap: () => widget.onSelect(network),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: _WifiRow(
              network: network,
              onDetails: () {
                setState(() {
                  _selected = network;
                });
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetails(BuildContext context, HomeWifiNetwork network) {
    final strength = _signalStrength(network.level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          network.ssid,
          style: context.theme.typography.base.copyWith(
            fontWeight: FontWeight.w700,
            color: context.theme.colors.foreground,
          ),
        ),
        const SizedBox(height: ThemeTokens.spaceXs),
        _DetailRow(label: 'Công nghệ', value: network.bandLabel),
        _DetailRow(
          label: 'Cường độ',
          value: '${network.level} dBm • $strength',
        ),
        _DetailRow(label: 'Bảo mật', value: network.securityLabel),
        const Spacer(),
        FButton(
          onPress: () {
            setState(() {
              _selected = null;
            });
          },
          style: FButtonStyle.ghost(),
          child: const Text('Quay lại danh sách'),
        ),
      ],
    );
  }

  String _signalStrength(int level) {
    if (level >= -50) {
      return 'Mạnh';
    }
    if (level >= -65) {
      return 'Tốt';
    }
    if (level >= -75) {
      return 'Trung bình';
    }
    return 'Yếu';
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.theme.colors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: context.theme.typography.xs.copyWith(
          color: context.theme.colors.secondaryForeground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconTag extends StatelessWidget {
  const _IconTag({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.theme.colors.secondary,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(
        icon,
        size: 14,
        color: context.theme.colors.secondaryForeground,
      ),
    );
    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: child,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WifiRow extends StatelessWidget {
  const _WifiRow({required this.network, required this.onDetails});

  final HomeWifiNetwork network;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final highlight = context.theme.colors.primary.withAlpha(32);
    final foreground = context.theme.colors.foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: network.isCurrent ? highlight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(_wifiSignalIcon(network.level), size: 16, color: foreground),
          const SizedBox(width: ThemeTokens.spaceSm),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    network.ssid,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.theme.typography.sm.copyWith(
                      fontWeight: network.isCurrent
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: foreground,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _Tag(label: network.bandLabel),
                const SizedBox(width: 6),
                _Tag(label: network.secured ? 'Bảo mật' : 'Mở'),
              ],
            ),
          ),
          const SizedBox(width: ThemeTokens.spaceSm),
          _IconTag(icon: FIcons.chevronRight, onTap: onDetails),
        ],
      ),
    );
  }
}

class _WifiPasswordSheet extends StatelessWidget {
  const _WifiPasswordSheet({
    required this.network,
    required this.password,
    required this.onPasswordChanged,
    required this.onConnect,
    required this.onCancel,
    required this.isConnecting,
  });

  final HomeWifiNetwork network;
  final String password;
  final ValueChanged<String> onPasswordChanged;
  final VoidCallback? onConnect;
  final VoidCallback onCancel;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    final needsPassword = network.secured;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            margin: const EdgeInsets.fromLTRB(
              ThemeTokens.spaceMd,
              0,
              ThemeTokens.spaceMd,
              ThemeTokens.spaceMd,
            ),
            decoration: BoxDecoration(
              color: context.theme.colors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.theme.colors.border),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ThemeTokens.spaceLg,
                ThemeTokens.spaceMd,
                ThemeTokens.spaceLg,
                ThemeTokens.spaceLg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    network.ssid,
                    style: context.theme.typography.xl.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.theme.colors.foreground,
                    ),
                  ),
                  const SizedBox(height: ThemeTokens.spaceXs),
                  Text(
                    needsPassword
                        ? 'Nhập mật khẩu để kết nối.'
                        : 'Mạng mở, không cần mật khẩu.',
                    style: context.theme.typography.sm.copyWith(
                      color: context.theme.colors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: ThemeTokens.spaceMd),
                  if (needsPassword)
                    FTextField(
                      label: const Text('Mật khẩu'),
                      obscureText: true,
                      control: FTextFieldControl.lifted(
                        value: TextEditingValue(
                          text: password,
                          selection: TextSelection.collapsed(
                            offset: password.length,
                          ),
                        ),
                        onChange: (value) => onPasswordChanged(value.text),
                      ),
                    ),
                  const SizedBox(height: ThemeTokens.spaceLg),
                  Row(
                    children: [
                      Expanded(
                        child: FButton(
                          onPress: onCancel,
                          style: FButtonStyle.ghost(),
                          child: const Text('Từ chối'),
                        ),
                      ),
                      const SizedBox(width: ThemeTokens.spaceSm),
                      Expanded(
                        child: FButton(
                          onPress: needsPassword && password.isEmpty
                              ? null
                              : onConnect,
                          child: isConnecting
                              ? const FCircularProgress()
                              : const Text('Kết nối'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmotionPicker extends StatefulWidget {
  const _EmotionPicker({
    required this.options,
    required this.selectedIndex,
    required this.palette,
  });

  final List<String> options;
  final int selectedIndex;
  final _EmotionPalette palette;

  @override
  State<_EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<_EmotionPicker> {
  final ScrollController _scrollController = ScrollController();
  static const double _itemSpacing = 12.0;
  double _itemExtent = 120.0;
  double _viewportWidth = 0;
  int _loopIndex = 0;
  int _lastSelectedIndex = -1;
  int _lastOptionsLength = 0;

  @override
  void initState() {
    super.initState();
    _syncLoopIndex();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToSelected(animated: false);
    });
  }

  @override
  void didUpdateWidget(covariant _EmotionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectionChanged = oldWidget.selectedIndex != widget.selectedIndex;
    final lengthChanged = oldWidget.options.length != widget.options.length;
    if (selectionChanged || lengthChanged) {
      _syncLoopIndex();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToSelected(animated: selectionChanged);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    if (widget.options.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.controlBackground(context),
        borderRadius: BorderRadius.circular(999),
      ),
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nextExtent = _resolveItemExtent(constraints.maxWidth);
            final extentChanged = (nextExtent - _itemExtent).abs() > 0.5;
            final widthChanged =
                (constraints.maxWidth - _viewportWidth).abs() > 0.5;
            _itemExtent = nextExtent;
            _viewportWidth = constraints.maxWidth;
            if (extentChanged || widthChanged) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                _jumpToSelected(animated: false);
              });
            }
            final itemCount = widget.options.length * 3;
            return Stack(
              children: [
                ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: itemCount,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: _itemSpacing),
                  itemBuilder: (context, index) {
                    final normalized = _normalizeIndex(index);
                    final isSelected = index == _loopIndex;
                    final scale = isSelected ? 1.0 : 0.92;
                    final opacity = isSelected ? 1.0 : 0.72;
                    return SizedBox(
                      width: _itemExtent,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        scale: scale,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOut,
                          opacity: opacity,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? palette.accent
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: palette.accent.withAlpha(90),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : null,
                            ),
                            alignment: Alignment.center,
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                              style: context.theme.typography.base.copyWith(
                                color: isSelected
                                    ? palette.accentForeground
                                    : palette.controlForeground(context),
                                fontWeight: FontWeight.w600,
                              ),
                              child: Text(
                                widget.options[normalized],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 20,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            palette.controlBackground(context),
                            palette.controlBackground(context).withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 20,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerRight,
                          end: Alignment.centerLeft,
                          colors: [
                            palette.controlBackground(context),
                            palette.controlBackground(context).withAlpha(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  double _resolveItemExtent(double maxWidth) {
    const visibleCount = 5;
    final totalSpacing = _itemSpacing * (visibleCount - 1);
    final raw = (maxWidth - totalSpacing) / visibleCount;
    return raw.clamp(90.0, 200.0);
  }

  int _normalizeIndex(int index) {
    final length = widget.options.length;
    if (length == 0) {
      return 0;
    }
    final mod = index % length;
    return mod < 0 ? mod + length : mod;
  }

  void _syncLoopIndex() {
    final length = widget.options.length;
    if (length == 0) {
      _loopIndex = 0;
      _lastSelectedIndex = -1;
      _lastOptionsLength = 0;
      return;
    }
    final selected = widget.selectedIndex.clamp(0, length - 1);
    _loopIndex = length + selected;
    _lastSelectedIndex = selected;
    _lastOptionsLength = length;
  }

  void _jumpToSelected({required bool animated}) {
    if (widget.options.isEmpty || _viewportWidth <= 0) {
      return;
    }
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToSelected(animated: animated);
      });
      return;
    }
    final length = widget.options.length;
    if (_lastOptionsLength != length ||
        _lastSelectedIndex != widget.selectedIndex) {
      _syncLoopIndex();
    }
    final target = _loopIndex * (_itemExtent + _itemSpacing);
    final centeredTarget = target - (_viewportWidth - _itemExtent) / 2;
    final position = _scrollController.position;
    final clamped = centeredTarget.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (animated) {
      _scrollController.animateTo(
        clamped,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(clamped);
    }
  }
}

class _SmileFacePainter extends CustomPainter {
  const _SmileFacePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final eyeOffsetX = size.width * 0.18;
    final eyeOffsetY = size.height * 0.08;
    final eyeRadius = size.width * 0.04;

    canvas.drawCircle(
      Offset(center.dx - eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(center.dx + eyeOffsetX, center.dy - eyeOffsetY),
      eyeRadius,
      dotPaint,
    );

    final nosePath = Path()
      ..moveTo(center.dx, center.dy - size.height * 0.02)
      ..lineTo(center.dx - size.width * 0.02, center.dy + size.height * 0.03)
      ..lineTo(center.dx + size.width * 0.02, center.dy + size.height * 0.03);
    canvas.drawPath(nosePath, linePaint);

    final smileRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy + size.height * 0.12),
      width: size.width * 0.32,
      height: size.height * 0.18,
    );
    canvas.drawArc(smileRect, 0, 3.14, false, linePaint);

    final hairPath = Path()
      ..moveTo(center.dx - size.width * 0.1, center.dy - size.height * 0.32)
      ..cubicTo(
        center.dx - size.width * 0.02,
        center.dy - size.height * 0.42,
        center.dx + size.width * 0.08,
        center.dy - size.height * 0.38,
        center.dx + size.width * 0.04,
        center.dy - size.height * 0.3,
      );
    canvas.drawPath(hairPath, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
