import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../../../capabilities/web_host/local_web_host_service.dart';
import '../../../capabilities/protocol/protocol.dart';
import '../../../core/theme/forui/theme_tokens.dart';
import '../../../features/home/domain/entities/home_system_status.dart';
import '../../../features/home/domain/entities/home_wifi_network.dart';
import '../../../theme/theme_palette.dart';
import 'helper_formatters.dart';
import '../ui_scale.dart';

class HomeSettingsSheet extends StatefulWidget {
  const HomeSettingsSheet({
    super.key,
    required this.volume,
    required this.audioDevice,
    required this.connectivity,
    required this.wifiName,
    required this.carrierName,
    required this.wifiNetworks,
    required this.wifiLoading,
    required this.wifiError,
    required this.batteryLevel,
    required this.batteryState,
    required this.onWifiRefresh,
    required this.onWifiSettings,
    required this.onWifiSelect,
    required this.autoReconnectEnabled,
    required this.onAutoReconnectChanged,
    required this.macAddress,
    required this.onMacAddressChanged,
    required this.onVolumeChanged,
    required this.textScale,
    required this.onTextScaleChanged,
    required this.cameraEnabled,
    required this.onCameraEnabledChanged,
    required this.cameraAspectRatio,
    required this.onCameraAspectChanged,
    required this.faceLandmarksEnabled,
    required this.faceMeshEnabled,
    required this.eyeTrackingEnabled,
    required this.onFaceLandmarksChanged,
    required this.onFaceMeshChanged,
    required this.onEyeTrackingChanged,
    required this.themeMode,
    required this.themePalette,
    required this.onThemePaletteChanged,
    required this.onSetLight,
    required this.onSetDark,
    required this.listeningMode,
    required this.onListeningModeChanged,
    required this.textSendMode,
    required this.onTextSendModeChanged,
    required this.connectGreeting,
    required this.onConnectGreetingChanged,
    required this.carouselHeight,
    required this.carouselAutoPlay,
    required this.carouselAutoPlayInterval,
    required this.carouselAnimationDuration,
    required this.carouselViewportFraction,
    required this.carouselEnlargeCenter,
    required this.onCarouselHeightChanged,
    required this.onCarouselAutoPlayChanged,
    required this.onCarouselIntervalChanged,
    required this.onCarouselAnimationChanged,
    required this.onCarouselViewportChanged,
    required this.onCarouselEnlargeChanged,
    required this.onOpenMcpFlow,
    // required this.onEnterKioskMode,
  });

  final double? volume;
  final HomeAudioDevice? audioDevice;
  final List<HomeConnectivity>? connectivity;
  final String? wifiName;
  final String? carrierName;
  final List<HomeWifiNetwork> wifiNetworks;
  final bool wifiLoading;
  final String? wifiError;
  final int? batteryLevel;
  final HomeBatteryState? batteryState;
  final VoidCallback? onWifiRefresh;
  final VoidCallback? onWifiSettings;
  final ValueChanged<HomeWifiNetwork>? onWifiSelect;
  final bool autoReconnectEnabled;
  final ValueChanged<bool> onAutoReconnectChanged;
  final String macAddress;
  final ValueChanged<String> onMacAddressChanged;
  final ValueChanged<double>? onVolumeChanged;
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;
  final bool cameraEnabled;
  final ValueChanged<bool> onCameraEnabledChanged;
  final double cameraAspectRatio;
  final ValueChanged<double> onCameraAspectChanged;
  final bool faceLandmarksEnabled;
  final bool faceMeshEnabled;
  final bool eyeTrackingEnabled;
  final ValueChanged<bool> onFaceLandmarksChanged;
  final ValueChanged<bool> onFaceMeshChanged;
  final ValueChanged<bool> onEyeTrackingChanged;
  final ThemeMode themeMode;
  final AppThemePalette themePalette;
  final ValueChanged<AppThemePalette> onThemePaletteChanged;
  final VoidCallback onSetLight;
  final VoidCallback onSetDark;
  final ListeningMode listeningMode;
  final ValueChanged<ListeningMode> onListeningModeChanged;
  final TextSendMode textSendMode;
  final ValueChanged<TextSendMode> onTextSendModeChanged;
  final String connectGreeting;
  final ValueChanged<String> onConnectGreetingChanged;
  final double carouselHeight;
  final bool carouselAutoPlay;
  final Duration carouselAutoPlayInterval;
  final Duration carouselAnimationDuration;
  final double carouselViewportFraction;
  final bool carouselEnlargeCenter;
  final ValueChanged<double> onCarouselHeightChanged;
  final ValueChanged<bool> onCarouselAutoPlayChanged;
  final ValueChanged<Duration> onCarouselIntervalChanged;
  final ValueChanged<Duration> onCarouselAnimationChanged;
  final ValueChanged<double> onCarouselViewportChanged;
  final ValueChanged<bool> onCarouselEnlargeChanged;
  final VoidCallback onOpenMcpFlow;
  // final VoidCallback onEnterKioskMode;

  @override
  State<HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

enum _SettingsSection {
  connectivity,
  audio,
  chat,
  camera,
  display,
  advanced,
}

class _HomeSettingsSheetState extends State<HomeSettingsSheet>
    with TickerProviderStateMixin {
  static const List<double> _textScaleSteps = [0.85, 0.95, 1.0, 1.2, 1.5];
  static const List<double> _cameraAspectRatios = [1.0, 4 / 3, 16 / 9];
  static const List<String> _cameraAspectLabels = ['1:1', '4:3', '16:9'];
  static const List<AppThemePalette> _paletteOptions = [
    AppThemePalette.neutral,
    AppThemePalette.green,
    AppThemePalette.lime,
  ];
  static const List<ListeningMode> _listeningModes = [
    ListeningMode.autoStop,
    ListeningMode.manual,
    ListeningMode.alwaysOn,
  ];
  static const List<String> _listeningModeLabels = [
    'Tự dừng',
    'Thủ công',
    'Luôn nghe',
  ];
  static const List<TextSendMode> _textSendModes = [
    TextSendMode.listenDetect,
    TextSendMode.text,
  ];
  static const List<String> _textSendModeLabels = ['Lắng nghe', 'Văn bản'];
  static const List<double> _carouselHeights = [160, 200, 240, 280];
  static const List<double> _carouselViewports = [0.6, 0.7, 0.8, 0.9];
  static const List<Duration> _carouselIntervals = [
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 4),
    Duration(seconds: 6),
  ];
  static const List<Duration> _carouselAnimations = [
    Duration(milliseconds: 400),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1000),
  ];
  late final Map<_SettingsSection, AnimationController> _sectionControllers;
  late final Map<_SettingsSection, Animation<double>> _sectionAnimations;
  late final Map<_SettingsSection, bool> _sectionExpanded;
  late String _greetingText;
  late double _sliderValue;
  late int _textScaleIndex;
  late int _paletteIndex;
  late int _cameraAspectIndex;
  late bool _cameraEnabledLocal;
  late bool _faceLandmarksLocal;
  late bool _faceMeshLocal;
  late bool _eyeTrackingLocal;
  late int _listeningModeIndex;
  late int _textSendModeIndex;
  late int _carouselHeightIndex;
  late int _carouselViewportIndex;
  late int _carouselIntervalIndex;
  late int _carouselAnimationIndex;
  late bool _carouselAutoPlayLocal;
  late bool _carouselEnlargeLocal;
  late bool _autoReconnectLocal;
  late String _macAddressText;
  final LocalWebHostService _webHost = LocalWebHostService.instance;
  StreamSubscription<LocalWebHostState>? _webHostStateSubscription;
  late LocalWebHostState _webHostState;

  @override
  void initState() {
    super.initState();
    _sliderValue = _coerceVolume(widget.volume);
    _textScaleIndex = _textScaleToIndex(widget.textScale);
    _paletteIndex = _paletteToIndex(widget.themePalette);
    _cameraAspectIndex = _cameraAspectToIndex(widget.cameraAspectRatio);
    _cameraEnabledLocal = widget.cameraEnabled;
    _faceLandmarksLocal = widget.faceLandmarksEnabled;
    _faceMeshLocal = widget.faceMeshEnabled;
    _eyeTrackingLocal = widget.eyeTrackingEnabled;
    _listeningModeIndex = _listeningModeToIndex(widget.listeningMode);
    _textSendModeIndex = _textSendModeToIndex(widget.textSendMode);
    _greetingText = widget.connectGreeting;
    _autoReconnectLocal = widget.autoReconnectEnabled;
    _macAddressText = widget.macAddress;
    _carouselHeightIndex = _carouselHeightToIndex(widget.carouselHeight);
    _carouselViewportIndex = _carouselViewportToIndex(
      widget.carouselViewportFraction,
    );
    _carouselIntervalIndex = _carouselIntervalToIndex(
      widget.carouselAutoPlayInterval,
    );
    _carouselAnimationIndex = _carouselAnimationToIndex(
      widget.carouselAnimationDuration,
    );
    _carouselAutoPlayLocal = widget.carouselAutoPlay;
    _carouselEnlargeLocal = widget.carouselEnlargeCenter;
    _sectionExpanded = {
      _SettingsSection.connectivity: false,
      _SettingsSection.audio: false,
      _SettingsSection.chat: false,
      _SettingsSection.camera: false,
      _SettingsSection.display: false,
      _SettingsSection.advanced: false,
    };
    _sectionControllers = {
      for (final section in _SettingsSection.values)
        section: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
          value: _sectionExpanded[section]! ? 1.0 : 0.0,
        ),
    };
    _sectionAnimations = {
      for (final section in _SettingsSection.values)
        section: CurvedAnimation(
          parent: _sectionControllers[section]!,
          curve: Curves.easeInOut,
        ),
    };
    _webHostState = _webHost.state;
    _webHostStateSubscription = _webHost.stateStream.listen((next) {
      if (!mounted) {
        return;
      }
      setState(() {
        _webHostState = next;
      });
    });
  }

  @override
  void didUpdateWidget(covariant HomeSettingsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _coerceVolume(widget.volume);
    if ((next - _sliderValue).abs() > 0.001) {
      setState(() {
        _sliderValue = next;
      });
    }
    final nextTextScaleIndex = _textScaleToIndex(widget.textScale);
    if (nextTextScaleIndex != _textScaleIndex) {
      setState(() {
        _textScaleIndex = nextTextScaleIndex;
      });
    }
    final nextPaletteIndex = _paletteToIndex(widget.themePalette);
    if (nextPaletteIndex != _paletteIndex) {
      setState(() {
        _paletteIndex = nextPaletteIndex;
      });
    }
    final nextAspectIndex = _cameraAspectToIndex(widget.cameraAspectRatio);
    if (nextAspectIndex != _cameraAspectIndex) {
      setState(() {
        _cameraAspectIndex = nextAspectIndex;
      });
    }
    final nextListeningIndex = _listeningModeToIndex(widget.listeningMode);
    if (nextListeningIndex != _listeningModeIndex) {
      setState(() {
        _listeningModeIndex = nextListeningIndex;
      });
    }
    final nextTextSendIndex = _textSendModeToIndex(widget.textSendMode);
    if (nextTextSendIndex != _textSendModeIndex) {
      setState(() {
        _textSendModeIndex = nextTextSendIndex;
      });
    }
    if (_greetingText != widget.connectGreeting) {
      setState(() {
        _greetingText = widget.connectGreeting;
      });
    }
    if (_autoReconnectLocal != widget.autoReconnectEnabled) {
      setState(() {
        _autoReconnectLocal = widget.autoReconnectEnabled;
      });
    }
    if (_macAddressText != widget.macAddress) {
      setState(() {
        _macAddressText = widget.macAddress;
      });
    }
    if (_cameraEnabledLocal != widget.cameraEnabled) {
      setState(() {
        _cameraEnabledLocal = widget.cameraEnabled;
      });
    }
    if (_faceLandmarksLocal != widget.faceLandmarksEnabled) {
      setState(() {
        _faceLandmarksLocal = widget.faceLandmarksEnabled;
      });
    }
    if (_faceMeshLocal != widget.faceMeshEnabled) {
      setState(() {
        _faceMeshLocal = widget.faceMeshEnabled;
      });
    }
    if (_eyeTrackingLocal != widget.eyeTrackingEnabled) {
      setState(() {
        _eyeTrackingLocal = widget.eyeTrackingEnabled;
      });
    }
    final nextCarouselHeight = _carouselHeightToIndex(widget.carouselHeight);
    if (nextCarouselHeight != _carouselHeightIndex) {
      setState(() {
        _carouselHeightIndex = nextCarouselHeight;
      });
    }
    final nextCarouselViewport = _carouselViewportToIndex(
      widget.carouselViewportFraction,
    );
    if (nextCarouselViewport != _carouselViewportIndex) {
      setState(() {
        _carouselViewportIndex = nextCarouselViewport;
      });
    }
    final nextCarouselInterval = _carouselIntervalToIndex(
      widget.carouselAutoPlayInterval,
    );
    if (nextCarouselInterval != _carouselIntervalIndex) {
      setState(() {
        _carouselIntervalIndex = nextCarouselInterval;
      });
    }
    final nextCarouselAnim = _carouselAnimationToIndex(
      widget.carouselAnimationDuration,
    );
    if (nextCarouselAnim != _carouselAnimationIndex) {
      setState(() {
        _carouselAnimationIndex = nextCarouselAnim;
      });
    }
    if (_carouselAutoPlayLocal != widget.carouselAutoPlay) {
      setState(() {
        _carouselAutoPlayLocal = widget.carouselAutoPlay;
      });
    }
    if (_carouselEnlargeLocal != widget.carouselEnlargeCenter) {
      setState(() {
        _carouselEnlargeLocal = widget.carouselEnlargeCenter;
      });
    }
  }

  double _coerceVolume(double? value) => (value ?? 0.35).clamp(0.0, 1.0);
  int _textScaleToIndex(double value) {
    var nearestIndex = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < _textScaleSteps.length; i++) {
      final diff = (value - _textScaleSteps[i]).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  int _paletteToIndex(AppThemePalette palette) {
    final index = _paletteOptions.indexOf(palette);
    return index < 0 ? 0 : index;
  }

  int _cameraAspectToIndex(double aspectRatio) {
    var nearestIndex = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < _cameraAspectRatios.length; i++) {
      final diff = (aspectRatio - _cameraAspectRatios[i]).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  int _listeningModeToIndex(ListeningMode mode) {
    final index = _listeningModes.indexOf(mode);
    return index < 0 ? 0 : index;
  }

  int _textSendModeToIndex(TextSendMode mode) {
    final index = _textSendModes.indexOf(mode);
    return index < 0 ? 0 : index;
  }

  int _carouselHeightToIndex(double height) {
    var nearestIndex = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < _carouselHeights.length; i++) {
      final diff = (height - _carouselHeights[i]).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  int _carouselViewportToIndex(double value) {
    var nearestIndex = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < _carouselViewports.length; i++) {
      final diff = (value - _carouselViewports[i]).abs();
      if (diff < nearestDiff) {
        nearestDiff = diff;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  int _carouselIntervalToIndex(Duration value) {
    var nearestIndex = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < _carouselIntervals.length; i++) {
      final diff = (value - _carouselIntervals[i]).abs();
      if (diff.inMilliseconds < nearestDiff) {
        nearestDiff = diff.inMilliseconds.toDouble();
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  int _carouselAnimationToIndex(Duration value) {
    var nearestIndex = 0;
    var nearestDiff = double.infinity;
    for (var i = 0; i < _carouselAnimations.length; i++) {
      final diff = (value - _carouselAnimations[i]).abs();
      if (diff.inMilliseconds < nearestDiff) {
        nearestDiff = diff.inMilliseconds.toDouble();
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }

  bool _isMacValid(String value) {
    final normalized = _normalizeMacInput(value);
    final regex = RegExp(r'^[0-9a-f]{2}(:[0-9a-f]{2}){5}$');
    if (!regex.hasMatch(normalized)) {
      return false;
    }
    return normalized != '02:00:00:00:00:00' &&
        normalized != '00:00:00:00:00:00';
  }

  String _normalizeMacInput(String input) {
    final hex = input.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '').toLowerCase();
    if (hex.isEmpty) {
      return '';
    }
    if (hex.length != 12) {
      return input.trim();
    }
    final buffer = StringBuffer();
    for (var i = 0; i < hex.length; i += 2) {
      if (i > 0) {
        buffer.write(':');
      }
      buffer.write(hex.substring(i, i + 2));
    }
    return buffer.toString();
  }

  @override
  void dispose() {
    _webHostStateSubscription?.cancel();
    for (final controller in _sectionControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = routeIcon(widget.audioDevice);
    final isMaxVolume = _sliderValue >= 0.99;
    final volumeSuffixIcon = isMaxVolume && route != null
        ? route
        : audioIcon(_sliderValue);
    final textScaleValue = _textScaleSteps[_textScaleIndex];
    final iconSize = scaledIconSize(context, 15);
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1.0).clamp(0.85, 1.5);
    final tabHeight = (35.0 * textScale).clamp(35.0, 56.0);
    final themeIndex = widget.themeMode == ThemeMode.dark ? 1 : 0;
    final paletteLabel = _paletteOptions[_paletteIndex].label;
    final cameraIndex = _cameraEnabledLocal ? 1 : 0;
    final cameraAspectLabel = _cameraAspectLabels[_cameraAspectIndex];
    final listeningModeLabel = _listeningModeLabels[_listeningModeIndex];
    final textSendModeLabel = _textSendModeLabels[_textSendModeIndex];
    final carouselHeightLabel =
        '${_carouselHeights[_carouselHeightIndex].round()}';
    final carouselViewportLabel =
        (_carouselViewports[_carouselViewportIndex] * 100).round();
    final carouselIntervalLabel =
        '${_carouselIntervals[_carouselIntervalIndex].inSeconds}s';
    final carouselAnimLabel =
        '${_carouselAnimations[_carouselAnimationIndex].inMilliseconds}ms';
    final hostUrl = _webHostState.url;
    final hostStatus = _webHostState.isRunning ? 'Đang chạy' : 'Đang dừng';
    final hostLabel =
        hostUrl ?? (_webHostState.message ?? 'Chưa có địa chỉ host');
    final macValid = _isMacValid(_macAddressText);
    final showMacError =
        _macAddressText.trim().isNotEmpty && !macValid;
    final offline = isOffline(widget.connectivity);
    final isWifiConnected =
        widget.connectivity?.contains(HomeConnectivity.wifi) ?? false;
    final isMobileConnected =
        widget.connectivity?.contains(HomeConnectivity.mobile) ?? false;
    final wifiStatus = offline
        ? 'Mất kết nối internet'
        : isWifiConnected
        ? (cleanWifiName(widget.wifiName) ?? 'Wi‑Fi')
        : isMobileConnected
        ? (widget.carrierName ?? '4G/5G')
        : networkDisplay(
            widget.connectivity,
            widget.wifiName,
            widget.carrierName,
          );
    final wifiStatusColor = offline
        ? context.theme.colors.destructive
        : context.theme.colors.mutedForeground;
    final wifiPrefixIcon = offline
        ? FIcons.wifiOff
        : isMobileConnected
        ? FIcons.cardSim
        : wifiIcon(widget.connectivity, widget.wifiName);
    FWidgetStateMap<IconThemeData> scaledItemIconStyle(
      FWidgetStateMap<IconThemeData> base,
    ) {
      final normal = base.resolve(<WidgetState>{});
      final disabled = base.resolve({WidgetState.disabled});
      return FWidgetStateMap({
        WidgetState.disabled: disabled.copyWith(size: iconSize),
        WidgetState.any: normal.copyWith(size: iconSize),
      });
    }

    FItemGroupStyle itemGroupStyle(FItemGroupStyle style) => style.copyWith(
      itemStyle: (itemStyle) => itemStyle.copyWith(
        contentStyle: (contentStyle) => contentStyle.copyWith(
          prefixIconStyle: scaledItemIconStyle(contentStyle.prefixIconStyle),
          suffixIconStyle: scaledItemIconStyle(contentStyle.suffixIconStyle),
        ),
      ),
    );

    Widget sectionHeader(String title, _SettingsSection section) {
      final expanded = _sectionExpanded[section] ?? false;
      return Padding(
        padding: const EdgeInsets.only(bottom: ThemeTokens.spaceXs),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
                fontWeight: FontWeight.w700,
              ),
            ),
            FButton.icon(
              onPress: () => _toggleSection(section),
              child: Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                size: iconSize,
              ),
            ),
          ],
        ),
      );
    }

    Widget sectionBody(_SettingsSection section, Widget child) {
      final animation = _sectionAnimations[section]!;
      return AnimatedBuilder(
        animation: animation,
        builder: (context, child) => FCollapsible(
          value: animation.value,
          child: child ?? const SizedBox.shrink(),
        ),
        child: child,
      );
    }

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
      ),
      child: IconTheme(
        data: IconTheme.of(context).copyWith(size: iconSize),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: ThemeTokens.spaceSm),
                  decoration: BoxDecoration(
                    color: context.theme.colors.mutedForeground.withAlpha(90),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Text(
                'Cài đặt',
                style: context.theme.typography.xl.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.theme.colors.foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kết nối, trò chuyện, âm thanh, camera, hiển thị, nâng cao',
                style: context.theme.typography.sm.copyWith(
                  color: context.theme.colors.mutedForeground,
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceSm),
              sectionHeader('Kết nối', _SettingsSection.connectivity),
              sectionBody(
                _SettingsSection.connectivity,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(wifiPrefixIcon, size: iconSize),
                      title: const Text('Wi‑Fi'),
                      details: Text(
                        wifiStatus,
                        style: context.theme.typography.sm.copyWith(
                          color: wifiStatusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      suffix: Icon(FIcons.chevronRight, size: iconSize),
                      onPress: widget.onWifiSettings,
                    ),
                    FItem(
                      prefix: Icon(Icons.sync, size: iconSize),
                      title: const Text('Tự kết nối lại'),
                      suffix: Text(
                        _autoReconnectLocal ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _autoReconnectLocal ? 1 : 0,
                            onChange: (index) {
                              final enabled = index == 1;
                              setState(() {
                                _autoReconnectLocal = enabled;
                              });
                              widget.onAutoReconnectChanged(enabled);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(
                        batteryIcon(widget.batteryLevel, widget.batteryState),
                        size: iconSize,
                      ),
                      title: const Text('Pin'),
                      suffix: Text(
                        batteryText(widget.batteryLevel),
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceMd),
              sectionHeader('Âm thanh', _SettingsSection.audio),
              sectionBody(
                _SettingsSection.audio,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(audioIcon(_sliderValue), size: iconSize),
                      title: const Text('Âm lượng'),
                      suffix: Icon(volumeSuffixIcon, size: iconSize),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          child: FSlider(
                            control: FSliderControl.liftedContinuous(
                              value: FSliderValue(max: _sliderValue),
                              onChange: (next) {
                                setState(() {
                                  _sliderValue = next.max;
                                });
                                widget.onVolumeChanged?.call(next.max);
                              },
                            ),
                            marks: const [
                              FSliderMark(value: 0, label: Text('0%')),
                              FSliderMark(value: 0.25, tick: false),
                              FSliderMark(value: 0.5),
                              FSliderMark(value: 0.75, tick: false),
                              FSliderMark(value: 1, label: Text('100%')),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceMd),
              sectionHeader('Trò chuyện', _SettingsSection.chat),
              sectionBody(
                _SettingsSection.chat,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(FIcons.mic, size: iconSize),
                      title: const Text('Chế độ nghe'),
                      suffix: Text(
                        listeningModeLabel,
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _listeningModeIndex,
                            onChange: (index) {
                              setState(() {
                                _listeningModeIndex = index;
                              });
                              widget.onListeningModeChanged(
                                _listeningModes[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('Tự dừng'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Thủ công'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Luôn nghe'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.chat_bubble_outline, size: iconSize),
                      title: const Text('Gửi text'),
                      suffix: Text(
                        textSendModeLabel,
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _textSendModeIndex,
                            onChange: (index) {
                              setState(() {
                                _textSendModeIndex = index;
                              });
                              widget.onTextSendModeChanged(
                                _textSendModes[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('Lắng nghe'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Văn bản'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(
                        Icons.mark_chat_read_outlined,
                        size: iconSize,
                      ),
                      title: const Text('Lời chào kết nối'),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTextField(
                          label: const Text('Nội dung gửi khi kết nối'),
                          hint: 'Ví dụ: Xin chào',
                          maxLines: 2,
                          control: FTextFieldControl.lifted(
                            value: TextEditingValue(
                              text: _greetingText,
                              selection: TextSelection.collapsed(
                                offset: _greetingText.length,
                              ),
                            ),
                            onChange: (value) {
                              setState(() {
                                _greetingText = value.text;
                              });
                              widget.onConnectGreetingChanged(value.text);
                            },
                          ),
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.memory_outlined, size: iconSize),
                      title: const Text('Địa chỉ MAC'),
                      details: Text(
                        'Cố định danh tính thiết bị khi kết nối',
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FTextField(
                              label: const Text('MAC cố định'),
                              hint: '02:00:00:00:00:01',
                              maxLines: 1,
                              control: FTextFieldControl.lifted(
                                value: TextEditingValue(
                                  text: _macAddressText,
                                  selection: TextSelection.collapsed(
                                    offset: _macAddressText.length,
                                  ),
                                ),
                                onChange: (value) {
                                  final raw = value.text;
                                  final normalized = _normalizeMacInput(raw);
                                  final isValid = _isMacValid(raw);
                                  final nextText =
                                      isValid ? normalized : raw;
                                  if (_macAddressText != nextText) {
                                    setState(() {
                                      _macAddressText = nextText;
                                    });
                                  }
                                  if (isValid) {
                                    widget.onMacAddressChanged(normalized);
                                  }
                                },
                              ),
                            ),
                            if (showMacError) ...[
                              const SizedBox(height: ThemeTokens.spaceXs),
                              Text(
                                'MAC không hợp lệ. Định dạng: XX:XX:XX:XX:XX:XX',
                                style: context.theme.typography.sm.copyWith(
                                  color: context.theme.colors.destructive,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceMd),
              sectionHeader('Camera', _SettingsSection.camera),
              sectionBody(
                _SettingsSection.camera,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(FIcons.camera, size: iconSize),
                      title: const Text('Camera'),
                      suffix: Text(
                        widget.cameraEnabled ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: cameraIndex,
                            onChange: (index) {
                              setState(() {
                                _cameraEnabledLocal = index == 1;
                              });
                              widget.onCameraEnabledChanged(
                                _cameraEnabledLocal,
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.zoom_in_outlined, size: iconSize),
                      title: const Text('Tỉ lệ khung hình'),
                      suffix: Text(
                        cameraAspectLabel,
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _cameraAspectIndex,
                            onChange: (index) {
                              setState(() {
                                _cameraAspectIndex = index;
                              });
                              widget.onCameraAspectChanged(
                                _cameraAspectRatios[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('1:1'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('4:3'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('16:9'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(
                        Icons.center_focus_strong_outlined,
                        size: iconSize,
                      ),
                      title: const Text('Mốc khuôn mặt'),
                      suffix: Text(
                        _faceLandmarksLocal ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _faceLandmarksLocal ? 1 : 0,
                            onChange: (index) {
                              final enabled = index == 1;
                              setState(() {
                                _faceLandmarksLocal = enabled;
                              });
                              widget.onFaceLandmarksChanged(enabled);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.grid_view_outlined, size: iconSize),
                      title: const Text('Facial Mesh'),
                      suffix: Text(
                        _faceMeshLocal ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _faceMeshLocal ? 1 : 0,
                            onChange: (index) {
                              final enabled = index == 1;
                              setState(() {
                                _faceMeshLocal = enabled;
                              });
                              widget.onFaceMeshChanged(enabled);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.visibility_outlined, size: iconSize),
                      title: const Text('Eye Tracking'),
                      suffix: Text(
                        _eyeTrackingLocal ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _eyeTrackingLocal ? 1 : 0,
                            onChange: (index) {
                              final enabled = index == 1;
                              setState(() {
                                _eyeTrackingLocal = enabled;
                              });
                              widget.onEyeTrackingChanged(enabled);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceMd),
              sectionHeader('Hiển thị', _SettingsSection.display),
              sectionBody(
                _SettingsSection.display,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(FIcons.moon, size: iconSize),
                      title: const Text('Giao diện'),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: themeIndex,
                            onChange: (index) {
                              if (index == 0) {
                                widget.onSetLight();
                              } else {
                                widget.onSetDark();
                              }
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Sáng'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Tối'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.palette_outlined, size: iconSize),
                      title: const Text('Chủ đề màu'),
                      suffix: Text(
                        paletteLabel,
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _paletteIndex,
                            onChange: (index) {
                              setState(() {
                                _paletteIndex = index;
                              });
                              widget.onThemePaletteChanged(
                                _paletteOptions[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('Mặc định'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Xanh lá'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Chanh'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              sectionBody(
                _SettingsSection.display,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(FIcons.aLargeSmall, size: iconSize),
                      title: const Text('Cỡ chữ'),
                      suffix: Text(
                        '${(textScaleValue * 100).round()}%',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _textScaleIndex,
                            onChange: (index) {
                              setState(() {
                                _textScaleIndex = index;
                              });
                              widget.onTextScaleChanged(_textScaleSteps[index]);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('85%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('95%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('100%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('120%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('150%'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              sectionBody(
                _SettingsSection.display,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(Icons.image_outlined, size: iconSize),
                      title: const Text('Chiều cao'),
                      suffix: Text(
                        '${carouselHeightLabel}px',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _carouselHeightIndex,
                            onChange: (index) {
                              setState(() {
                                _carouselHeightIndex = index;
                              });
                              widget.onCarouselHeightChanged(
                                _carouselHeights[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('160'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('200'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('240'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('280'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.play_arrow_rounded, size: iconSize),
                      title: const Text('Tự chạy'),
                      suffix: Text(
                        _carouselAutoPlayLocal ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _carouselAutoPlayLocal ? 1 : 0,
                            onChange: (index) {
                              final enabled = index == 1;
                              setState(() {
                                _carouselAutoPlayLocal = enabled;
                              });
                              widget.onCarouselAutoPlayChanged(enabled);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.timer_outlined, size: iconSize),
                      title: const Text('Chu kỳ'),
                      suffix: Text(
                        carouselIntervalLabel,
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _carouselIntervalIndex,
                            onChange: (index) {
                              setState(() {
                                _carouselIntervalIndex = index;
                              });
                              widget.onCarouselIntervalChanged(
                                _carouselIntervals[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('2s'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('3s'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('4s'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('6s'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.speed_rounded, size: iconSize),
                      title: const Text('Tốc độ chạy'),
                      suffix: Text(
                        carouselAnimLabel,
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _carouselAnimationIndex,
                            onChange: (index) {
                              setState(() {
                                _carouselAnimationIndex = index;
                              });
                              widget.onCarouselAnimationChanged(
                                _carouselAnimations[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('400'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('700'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('1000'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(
                        Icons.view_carousel_outlined,
                        size: iconSize,
                      ),
                      title: const Text('Hiển thị'),
                      suffix: Text(
                        '$carouselViewportLabel%',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _carouselViewportIndex,
                            onChange: (index) {
                              setState(() {
                                _carouselViewportIndex = index;
                              });
                              widget.onCarouselViewportChanged(
                                _carouselViewports[index],
                              );
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          scrollable: false,
                          children: const [
                            FTabEntry(
                              label: Text('60%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('70%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('80%'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('90%'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.open_in_full_outlined, size: iconSize),
                      title: const Text('Phóng to giữa'),
                      suffix: Text(
                        _carouselEnlargeLocal ? 'Bật' : 'Tắt',
                        style: context.theme.typography.base.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.theme.colors.foreground,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: FTabs(
                          control: FTabControl.lifted(
                            index: _carouselEnlargeLocal ? 1 : 0,
                            onChange: (index) {
                              final enabled = index == 1;
                              setState(() {
                                _carouselEnlargeLocal = enabled;
                              });
                              widget.onCarouselEnlargeChanged(enabled);
                            },
                          ),
                          style: (style) =>
                              style.copyWith(spacing: 0, height: tabHeight),
                          children: const [
                            FTabEntry(
                              label: Text('Tắt'),
                              child: SizedBox.shrink(),
                            ),
                            FTabEntry(
                              label: Text('Bật'),
                              child: SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: ThemeTokens.spaceMd),
              sectionHeader('Nâng cao', _SettingsSection.advanced),
              sectionBody(
                _SettingsSection.advanced,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    FItem(
                      prefix: Icon(Icons.extension_outlined, size: iconSize),
                      title: const Text('MCP Server Flow'),
                      details: Text(
                        'Quản lý tools, JSON‑RPC và host nội bộ',
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                    ),
                    FItem(
                      prefix: Icon(Icons.lan_outlined, size: iconSize),
                      title: const Text('Địa chỉ truy cập'),
                      details: Text(
                        hostLabel,
                        style: context.theme.typography.sm.copyWith(
                          color: context.theme.colors.mutedForeground,
                        ),
                      ),
                      suffix: Text(
                        hostStatus,
                        style: context.theme.typography.sm.copyWith(
                          color: _webHostState.isRunning
                              ? context.theme.colors.primary
                              : context.theme.colors.destructive,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FItem.raw(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: ThemeTokens.spaceSm,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: ThemeTokens.buttonHeight,
                          child: FButton(
                            onPress: widget.onOpenMcpFlow,
                            child: const Text('Mở MCP Manager'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              sectionBody(
                _SettingsSection.advanced,
                FItemGroup(
                  divider: FItemDivider.none,
                  style: itemGroupStyle,
                  children: [
                    // Kiosk controls temporarily disabled.
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSection(_SettingsSection section) {
    final current = _sectionExpanded[section] ?? false;
    final next = !current;
    setState(() {
      _sectionExpanded[section] = next;
    });
    final controller = _sectionControllers[section]!;
    if (next) {
      controller.forward();
    } else {
      controller.reverse();
    }
  }
}
