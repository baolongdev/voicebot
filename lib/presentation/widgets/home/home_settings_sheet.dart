import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

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
    required this.onVolumeChanged,
    required this.textScale,
    required this.onTextScaleChanged,
    required this.themeMode,
    required this.themePalette,
    required this.onThemePaletteChanged,
    required this.onSetLight,
    required this.onSetDark,
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
  final ValueChanged<double>? onVolumeChanged;
  final double textScale;
  final ValueChanged<double> onTextScaleChanged;
  final ThemeMode themeMode;
  final AppThemePalette themePalette;
  final ValueChanged<AppThemePalette> onThemePaletteChanged;
  final VoidCallback onSetLight;
  final VoidCallback onSetDark;

  @override
  State<HomeSettingsSheet> createState() => _HomeSettingsSheetState();
}

class _HomeSettingsSheetState extends State<HomeSettingsSheet> {
  static const List<double> _textScaleSteps = [
    0.85,
    0.95,
    1.0,
    1.2,
    1.5,
  ];
  static const List<AppThemePalette> _paletteOptions = [
    AppThemePalette.neutral,
    AppThemePalette.green,
    AppThemePalette.lime,
  ];
  late double _sliderValue;
  late int _textScaleIndex;
  late int _paletteIndex;

  @override
  void initState() {
    super.initState();
    _sliderValue = _coerceVolume(widget.volume);
    _textScaleIndex = _textScaleToIndex(widget.textScale);
    _paletteIndex = _paletteToIndex(widget.themePalette);
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
  }

  double _coerceVolume(double? value) =>
      (value ?? 0.35).clamp(0.0, 1.0);
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

  @override
  Widget build(BuildContext context) {
    final route = routeIcon(widget.audioDevice);
    final isMaxVolume = _sliderValue >= 0.99;
    final volumeSuffixIcon = isMaxVolume && route != null
        ? route
        : audioIcon(_sliderValue);
    final textScaleValue = _textScaleSteps[_textScaleIndex];
    final iconSize = scaledIconSize(context, 15);
    final textScale = MediaQuery.textScaleFactorOf(context).clamp(0.85, 1.5);
    final tabHeight = (35.0 * textScale).clamp(35.0, 56.0);
    final themeIndex = widget.themeMode == ThemeMode.dark ? 1 : 0;
    final paletteLabel = _paletteOptions[_paletteIndex].label;
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
              'Wi‑Fi, pin, âm lượng, giao diện, cỡ chữ',
              style: context.theme.typography.sm.copyWith(
                color: context.theme.colors.mutedForeground,
              ),
            ),
            const SizedBox(height: ThemeTokens.spaceSm),
            FItemGroup(
              divider: FItemDivider.none,
              style: (style) => style.copyWith(
                itemStyle: (itemStyle) => itemStyle.copyWith(
                  contentStyle: (contentStyle) => contentStyle.copyWith(
                    prefixIconStyle: scaledItemIconStyle(
                      contentStyle.prefixIconStyle,
                    ),
                    suffixIconStyle: scaledItemIconStyle(
                      contentStyle.suffixIconStyle,
                    ),
                  ),
                ),
              ),
              children: [
                FItem(
                  prefix: Icon(FIcons.wifi, size: iconSize),
                  title: const Text('Wi‑Fi'),
                  suffix: Icon(FIcons.chevronRight, size: iconSize),
                  onPress: widget.onWifiSettings,
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
                FItem(
                  prefix: Icon(audioIcon(_sliderValue), size: iconSize),
                  title: const Text('Âm lượng'),
                  suffix: Icon(volumeSuffixIcon, size: iconSize),
                ),
                FItem.raw(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: ThemeTokens.spaceSm),
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
                FItem(
                  prefix: Icon(FIcons.moon, size: iconSize),
                  title: const Text('Giao diện'),
                ),
                FItem.raw(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: ThemeTokens.spaceSm),
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
                      style: (style) => style.copyWith(
                        spacing: 0,
                        height: tabHeight,
                      ),
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
                    padding: const EdgeInsets.only(bottom: ThemeTokens.spaceSm),
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
                      style: (style) => style.copyWith(
                        spacing: 0,
                        height: tabHeight,
                      ),
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
                    padding: const EdgeInsets.only(bottom: ThemeTokens.spaceSm),
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
                      style: (style) => style.copyWith(
                        spacing: 0,
                        height: tabHeight,
                      ),
                      scrollable: false,
                      children: const [
                        FTabEntry(label: Text('85%'), child: SizedBox.shrink()),
                        FTabEntry(label: Text('95%'), child: SizedBox.shrink()),
                        FTabEntry(label: Text('100%'), child: SizedBox.shrink()),
                        FTabEntry(label: Text('120%'), child: SizedBox.shrink()),
                        FTabEntry(label: Text('150%'), child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
    );
  }
}
