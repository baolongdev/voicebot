import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audio_router/audio_router.dart';
import 'package:audio_router/audio_router_platform_interface.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:carrier_info/carrier_info.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:forui/forui.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:app_settings/app_settings.dart';
import 'package:plugin_wifi_connect/plugin_wifi_connect.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../../core/system/ota/model/ota_result.dart';
import '../../core/system/ota/ota.dart' as core_ota;
import '../../core/theme/forui/theme_tokens.dart';
import '../../di/locator.dart';
import '../../features/chat/application/state/chat_controller.dart';
import '../../features/form/domain/models/server_form_data.dart';
import '../../features/form/infrastructure/repositories/settings_repository.dart';

class V2HomePage extends StatefulWidget {
  const V2HomePage({super.key});

  @override
  State<V2HomePage> createState() => _V2HomePageState();
}

class _V2HomePageState extends State<V2HomePage> {
  final Battery _battery = Battery();
  final Connectivity _connectivityService = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();
  final AudioRouter _audioRouter = AudioRouter();
  late final ChatController _chatController = getIt<ChatController>();
  StreamSubscription<BatteryState>? _batteryStateSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<AudioDevice?>? _audioDeviceSub;
  Timer? _clockTimer;
  int? _batteryLevel;
  BatteryState? _batteryState;
  List<ConnectivityResult>? _connectivity;
  String? _wifiName;
  String? _carrierName;
  double? _volume;
  AudioDevice? _audioDevice;
  DateTime _now = DateTime.now();
  String _wifiPassword = '';
  List<_WifiNetwork> _wifiNetworks = [];
  bool _wifiLoading = false;
  String? _wifiError;
  final GlobalKey _headerKey = GlobalKey();
  double _headerHeight = 0;
  bool _isChatConnecting = false;
  bool _chatReady = false;

  @override
  void initState() {
    super.initState();
    _initBattery();
    _initConnectivity();
    _initVolume();
    _initCarrier();
    _initAudioRoute();
    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  Future<void> _initBattery() async {
    final level = await _battery.batteryLevel;
    if (!mounted) {
      return;
    }
    setState(() {
      _batteryLevel = level;
    });
    _batteryStateSub = _battery.onBatteryStateChanged.listen((state) {
      if (!mounted) {
        return;
      }
      setState(() {
        _batteryState = state;
      });
    });
  }

  Future<void> _initConnectivity() async {
    final initial = await _connectivityService.checkConnectivity();
    if (!mounted) {
      return;
    }
    setState(() {
      _connectivity = initial;
    });
    await _updateWifiName();
    _connectivitySub =
        _connectivityService.onConnectivityChanged.listen((results) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectivity = results;
      });
      _updateWifiName();
    });
  }

  Future<void> _initVolume() async {
    FlutterVolumeController.addListener(_handleVolume);
    final volume = await FlutterVolumeController.getVolume();
    if (!mounted) {
      return;
    }
    setState(() {
      _volume = volume;
    });
  }

  Future<void> _initAudioRoute() async {
    _audioDeviceSub = _audioRouter.currentDeviceStream.listen((device) {
      if (!mounted) {
        return;
      }
      setState(() {
        _audioDevice = device;
      });
    });
    try {
      final device = await AudioRouterPlatform.instance.getCurrentDevice();
      if (!mounted) {
        return;
      }
      setState(() {
        _audioDevice = device;
      });
    } catch (_) {}
  }

  Future<void> _updateWifiName() async {
    try {
      final name = await _networkInfo.getWifiName();
      if (!mounted) {
        return;
      }
      setState(() {
        _wifiName = name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _wifiName = null;
      });
    }
  }

  Future<void> _initCarrier() async {
    String? name;
    try {
      if (Platform.isAndroid) {
        final info = await CarrierInfo.getAndroidInfo();
        name = _androidCarrierName(info);
      } else if (Platform.isIOS) {
        final info = await CarrierInfo.getIosInfo();
        name = _iosCarrierName(info);
      }
    } catch (_) {
      name = null;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _carrierName = name;
    });
  }

  String? _androidCarrierName(AndroidCarrierData? info) {
    if (info == null) {
      return null;
    }
    final telephony = info.telephonyInfo;
    if (telephony.isNotEmpty) {
      final first = telephony.first;
      final name = _firstNonEmpty([
        first.networkOperatorName,
        first.carrierName,
        first.displayName,
      ]);
      if (name != null) {
        return name;
      }
    }
    final subs = info.subscriptionsInfo;
    if (subs.isNotEmpty) {
      final first = subs.first;
      return _firstNonEmpty([
        first.displayName,
      ]);
    }
    return null;
  }

  String? _iosCarrierName(IosCarrierData? info) {
    if (info == null) {
      return null;
    }
    final carriers = info.carrierData;
    if (carriers.isEmpty) {
      return null;
    }
    final first = carriers.first;
    return _firstNonEmpty([
      first.carrierName,
      first.mobileNetworkCode,
      first.mobileCountryCode,
    ]);
  }

  String? _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  void _handleVolume(double volume) {
    if (!mounted) {
      return;
    }
    setState(() {
      _volume = volume;
    });
  }

  @override
  void dispose() {
    _batteryStateSub?.cancel();
    _connectivitySub?.cancel();
    _audioDeviceSub?.cancel();
    _clockTimer?.cancel();
    FlutterVolumeController.removeListener();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleHeaderMeasure();
    final activation = getIt<core_ota.Ota>().otaResult?.activation;
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
                  color: const Color(0xFFAEE2FF),
                  padding: const EdgeInsets.all(8),
                  child: _HomeHeader(
                    now: _now,
                    batteryLevel: _batteryLevel,
                    batteryState: _batteryState,
                    connectivity: _connectivity,
                    volume: _volume,
                    audioDevice: _audioDevice,
                    wifiName: _wifiName,
                    carrierName: _carrierName,
                    wifiNetworks: _wifiNetworks,
                    wifiLoading: _wifiLoading,
                    wifiError: _wifiError,
                    onWifiTap: _refreshWifiNetworks,
                    onWifiSelect: _openWifiPasswordSheet,
                  ),
                ),
              ),
              SizedBox(height: _headerSpacing()),
              const Expanded(child: _HomeContent()),
              SizedBox(height: _headerSpacing()),
              _HomeFooter(
                chatController: _chatController,
                activation: activation,
                onConnect: _handleConnectChat,
                isConnecting: _isChatConnecting,
                isConnected: _chatReady,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleConnectChat() async {
    if (_isChatConnecting) {
      return;
    }
    setState(() {
      _isChatConnecting = true;
    });
    final settings = getIt<SettingsRepository>();
    final ota = getIt<core_ota.Ota>();
    final needsConfig = (settings.webSocketUrl ?? '').isEmpty ||
        (settings.webSocketToken ?? '').isEmpty ||
        ota.deviceInfo == null;
    if (needsConfig) {
      await ota.checkVersion(const XiaoZhiConfig().qtaUrl);
      final otaResult = ota.otaResult;
      final websocket = otaResult?.websocket;
      if (websocket != null) {
        if (websocket.url.isNotEmpty) {
          settings.webSocketUrl = websocket.url;
        }
        if (websocket.token.isNotEmpty) {
          settings.webSocketToken = websocket.token;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {});
    }
    final stillMissing = (settings.webSocketUrl ?? '').isEmpty ||
        (settings.webSocketToken ?? '').isEmpty ||
        ota.deviceInfo == null;
    if (stillMissing) {
      if (mounted) {
        showFToast(
          context: context,
          alignment: FToastAlignment.topRight,
          icon: const Icon(FIcons.triangleAlert),
          title: const Text('Chưa có cấu hình XiaoZhi'),
          description: const Text('Vui lòng cấu hình server/OTA trước.'),
        );
      }
      setState(() {
        _isChatConnecting = false;
        _chatReady = false;
      });
      return;
    }
    await _chatController.initialize();
    if (!mounted) {
      return;
    }
    final error = _chatController.connectionError;
    setState(() {
      _isChatConnecting = false;
      _chatReady = error == null || error.isEmpty;
    });
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

  double _headerSpacing() {
    if (_headerHeight <= 0) {
      return ThemeTokens.spaceSm;
    }
    final spacing = _headerHeight * 0.15;
    return spacing.clamp(8.0, 24.0);
  }

  Future<List<_WifiNetwork>> _scanWifiNetworks() async {
    final current = _HomeHeader._cleanWifiName(_wifiName);
    if (!Platform.isAndroid) {
      if (current != null && current.isNotEmpty) {
        return [
          _WifiNetwork(
            ssid: current,
            secured: true,
            level: -50,
            bandLabel: _bandLabel(current),
            securityLabel: 'Đang kết nối',
            capabilities: '',
            isCurrent: true,
          ),
        ];
      }
      return [];
    }
    final canStart = await WiFiScan.instance.canStartScan(
      askPermissions: true,
    );
    if (canStart == CanStartScan.yes) {
      await WiFiScan.instance.startScan();
    }

    final canGet = await WiFiScan.instance.canGetScannedResults(
      askPermissions: true,
    );
    if (canGet != CanGetScannedResults.yes) {
      return [];
    }

    final results = await WiFiScan.instance.getScannedResults();
    final networks = results
        .where((ap) => ap.ssid.isNotEmpty)
        .map((ap) => _WifiNetwork(
              ssid: ap.ssid,
              secured: _isSecured(ap.capabilities),
              level: ap.level,
              bandLabel: _bandLabel(ap.ssid),
              securityLabel: _securityLabel(ap.capabilities),
              capabilities: ap.capabilities,
              isCurrent: current != null && ap.ssid == current,
            ))
        .toList()
      ..sort((a, b) {
        if (a.isCurrent != b.isCurrent) {
          return a.isCurrent ? -1 : 1;
        }
        return b.level.compareTo(a.level);
      });

    return networks;
  }

  bool _isSecured(String capabilities) {
    final caps = capabilities.toUpperCase();
    return caps.contains('WPA') ||
        caps.contains('WEP') ||
        caps.contains('EAP') ||
        caps.contains('SAE') ||
        caps.contains('OWE');
  }

  String _bandLabel(String ssid) {
    final upper = ssid.toUpperCase();
    if (upper.contains('5G') || upper.contains('5GHZ')) {
      return '5G';
    }
    return '2.4G';
  }

  String _securityLabel(String capabilities) {
    final caps = capabilities.toUpperCase();
    if (caps.contains('WPA3') || caps.contains('SAE')) {
      return 'WPA3';
    }
    if (caps.contains('WPA2')) {
      return 'WPA2';
    }
    if (caps.contains('WPA')) {
      return 'WPA';
    }
    if (caps.contains('WEP')) {
      return 'WEP';
    }
    if (caps.contains('OWE')) {
      return 'OWE';
    }
    return 'Open';
  }

  Future<void> _refreshWifiNetworks() async {
    setState(() {
      _wifiLoading = true;
      _wifiError = null;
    });
    try {
      final result = await _scanWifiNetworks();
      if (!mounted) {
        return;
      }
      setState(() {
        _wifiNetworks = result;
        _wifiLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _wifiLoading = false;
        _wifiError = 'Không thể quét Wi‑Fi, thử lại sau.';
      });
    }
  }

  void _openWifiPasswordSheet(_WifiNetwork network) {
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
              final success = await _connectToWifi(network, _wifiPassword);
              if (!mounted) {
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

  Future<bool> _connectToWifi(_WifiNetwork network, String password) async {
    try {
      if (!network.secured) {
        await PluginWifiConnect.connectToSecureNetwork(
          network.ssid,
          '',
          isWep: false,
          isWpa3: false,
        );
        return true;
      }
      final caps = network.capabilities.toUpperCase();
      final isWep = caps.contains('WEP');
      final isWpa3 = caps.contains('WPA3') || caps.contains('SAE');
      await PluginWifiConnect.connectToSecureNetwork(
        network.ssid,
        password,
        isWep: isWep,
        isWpa3: isWpa3,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshNetworkStatus() async {
    for (var attempt = 0; attempt < 5; attempt += 1) {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) {
        return;
      }
      final connectivity = await _connectivityService.checkConnectivity();
      if (!mounted) {
        return;
      }
      setState(() {
        _connectivity = connectivity;
      });
      await _updateWifiName();
      if (!mounted) {
        return;
      }
      final name = _HomeHeader._cleanWifiName(_wifiName);
      if (name != null && name.isNotEmpty) {
        setState(() {
          _connectivity = [ConnectivityResult.wifi];
        });
        return;
      }
    }
  }
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
    required this.wifiNetworks,
    required this.wifiLoading,
    required this.wifiError,
    this.onWifiTap,
    this.onWifiSelect,
  });

  final DateTime now;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final List<ConnectivityResult>? connectivity;
  final double? volume;
  final AudioDevice? audioDevice;
  final String? wifiName;
  final String? carrierName;
  final List<_WifiNetwork>? wifiNetworks;
  final bool? wifiLoading;
  final String? wifiError;
  final VoidCallback? onWifiTap;
  final ValueChanged<_WifiNetwork>? onWifiSelect;

  @override
  Widget build(BuildContext context) {
    final dateText = '${_two(now.day)}/${_two(now.month)}/${now.year}';
    final timeText = '${_two(now.hour)}:${_two(now.minute)}';
    final networkDisplay = _networkDisplay(connectivity, wifiName, carrierName);
    final isOffline = _isOffline(connectivity);
    final headerTextColor = const Color(0xFF4B7CA6);
    final wifiTextColor = isOffline
        ? context.theme.colors.destructive
        : headerTextColor;
    final wifiEnabled = connectivity?.contains(ConnectivityResult.wifi) ?? false;

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
                    _AudioStatusValue(
                      volume: volume,
                      audioDevice: audioDevice,
                      color: headerTextColor,
                    ),
                    const SizedBox(width: ThemeTokens.spaceSm),
                    FPopover(
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
                      popoverBuilder: (context, controller) => _WifiPopoverContent(
                        isLoading: wifiLoading ?? false,
                        errorMessage: wifiError,
                        networks: wifiNetworks ?? const [],
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
                              description:
                                  const Text('Bật Wi‑Fi để xem danh sách.'),
                              suffixBuilder: (context, entry) => FButton(
                                mainAxisSize: MainAxisSize.min,
                                onPress: () {
                                  entry.dismiss();
                                  if (Platform.isAndroid) {
                                    AppSettings.openAppSettings(
                                      type: AppSettingsType.wifi,
                                    );
                                  } else {
                                    AppSettings.openAppSettings();
                                  }
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

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        color: const Color(0xFFFAD7E6),
        child: Center(
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              color: Color(0xFFF59BC4),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(painter: _SmileFacePainter()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeFooter extends StatelessWidget {
  const _HomeFooter({
    required this.chatController,
    required this.activation,
    required this.onConnect,
    required this.isConnecting,
    required this.isConnected,
  });

  final ChatController chatController;
  final Activation? activation;
  final VoidCallback onConnect;
  final bool isConnecting;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: ThemeTokens.spaceMd,
        vertical: ThemeTokens.spaceSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _EmotionPicker(
            options: const [
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
            ],
            selectedIndex: 0,
          ),
          const SizedBox(height: ThemeTokens.spaceSm),
          if (activation != null) ...[
            SizedBox(
              width: double.infinity,
              child: FTextField(
                label: const Text('Activation'),
                readOnly: true,
                control: FTextFieldControl.managed(
                  initial: TextEditingValue(text: activation?.code ?? ''),
                ),
              ),
            ),
          ] else ...[
            AnimatedBuilder(
              animation: chatController,
              builder: (context, _) {
                final lastMessage = chatController.messages.isNotEmpty
                    ? chatController.messages.last.text
                    : 'Transcript / lời thoại';
                return SizedBox(
                  width: double.infinity,
                  child: Text(
                    lastMessage,
                    textAlign: TextAlign.center,
                    style: context.theme.typography.xl.copyWith(
                      color: context.theme.colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                );
              },
            ),
          ],
          const SizedBox(height: ThemeTokens.spaceSm),
          const _AudioWaveIndicator(),
          const SizedBox(height: ThemeTokens.spaceSm),
          Row(
            children: [
              const Spacer(),
              Row(
                children: [
                  FButton(
                    onPress: () {},
                    style: FButtonStyle.secondary(
                      (style) => style.copyWith(
                        contentStyle: (content) => content.copyWith(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    mainAxisSize: MainAxisSize.min,
                    child: const Text('Hủy'),
                  ),
                  const SizedBox(width: ThemeTokens.spaceSm),
                  FButton(
                    onPress: isConnected || isConnecting ? null : onConnect,
                    style: FButtonStyle.primary(
                      (style) => style.copyWith(
                        contentStyle: (content) => content.copyWith(
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
}

class _AudioWaveIndicator extends StatefulWidget {
  const _AudioWaveIndicator();

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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.theme.colors.mutedForeground;
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value * math.pi * 2;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _AudioWaveIndicator._heights.length; i++)
                ...[
                  Container(
                    width: 5,
                    height: _scaledHeight(
                      _AudioWaveIndicator._heights[i],
                      t,
                      i,
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

  double _scaledHeight(double base, double t, int index) {
    final phase = index * 0.45;
    final wave = (math.sin(t + phase) + 1) / 2;
    return base * (0.7 + 0.3 * wave);
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({
    required this.label,
    required this.value,
    this.textAlign = TextAlign.start,
    this.isHorizontal = false,
    this.color,
  });

  final String label;
  final String value;
  final TextAlign textAlign;
  final bool isHorizontal;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final typography = context.theme.typography;
    final colors = context.theme.colors;
    final alignment = _alignmentFromTextAlign(textAlign);

    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            label,
            style: typography.base.copyWith(
              color: color ?? colors.mutedForeground,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: ThemeTokens.spaceXs),
          Text(
            value,
            style: typography.base.copyWith(
              color: color ?? colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: [
        Text(
          label,
          style: typography.base.copyWith(
            color: color ?? colors.mutedForeground,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: typography.base.copyWith(
            color: color ?? colors.foreground,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  static CrossAxisAlignment _alignmentFromTextAlign(TextAlign align) {
    switch (align) {
      case TextAlign.center:
        return CrossAxisAlignment.center;
      case TextAlign.right:
      case TextAlign.end:
        return CrossAxisAlignment.end;
      case TextAlign.left:
      case TextAlign.start:
      default:
        return CrossAxisAlignment.start;
    }
  }
}

class _StatusIconValue extends StatelessWidget {
  const _StatusIconValue({
    required this.icon,
    required this.value,
    this.color,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final Color? color;
  final VoidCallback? onTap;

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

    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: ThemeTokens.spaceXs,
          vertical: 2,
        ),
        child: content,
      ),
    );
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
    final routeIcon =
        isMax ? _HomeHeader._routeIcon(audioDevice) : null;
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

class _WifiNetwork {
  const _WifiNetwork({
    required this.ssid,
    required this.secured,
    required this.level,
    required this.bandLabel,
    required this.securityLabel,
    required this.capabilities,
    this.isCurrent = false,
  });

  final String ssid;
  final bool secured;
  final int level;
  final String bandLabel;
  final String securityLabel;
  final String capabilities;
  final bool isCurrent;
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

  final List<_WifiNetwork> networks;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRefresh;
  final ValueChanged<_WifiNetwork> onSelect;

  @override
  State<_WifiPopoverContent> createState() => _WifiPopoverContentState();
}

class _WifiPopoverContentState extends State<_WifiPopoverContent> {
  _WifiNetwork? _selected;

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
              color: Colors.black.withAlpha(26),
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
              Expanded(child: _selected == null ? _buildList(context) : _buildDetails(context, _selected!)),
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

  Widget _buildDetails(BuildContext context, _WifiNetwork network) {
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
  const _IconTag({
    required this.icon,
    this.onTap,
  });

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
  const _WifiRow({
    required this.network,
    required this.onDetails,
  });

  final _WifiNetwork network;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark
        ? const Color(0xFF1D324B)
        : const Color(0xFFD9EEFF);
    final foreground = context.theme.colors.foreground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: network.isCurrent ? highlight : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _wifiSignalIcon(network.level),
            size: 16,
            color: foreground,
          ),
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
          _IconTag(
            icon: FIcons.chevronRight,
            onTap: onDetails,
          ),
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

  final _WifiNetwork network;
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
  });

  final List<String> options;
  final int selectedIndex;

  @override
  State<_EmotionPicker> createState() => _EmotionPickerState();
}

class _EmotionPickerState extends State<_EmotionPicker> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollKey = GlobalKey();
  late List<GlobalKey> _itemKeys;
  late int _loopIndex;

  @override
  void initState() {
    super.initState();
    _itemKeys = _buildKeys(widget.options.length);
    _loopIndex = _baseOffset(widget.options.length) + widget.selectedIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _jumpToMiddleSegment();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerSelected(animated: false);
      });
    });
  }

  @override
  void didUpdateWidget(covariant _EmotionPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options.length != widget.options.length) {
      _itemKeys = _buildKeys(widget.options.length);
      _loopIndex = _baseOffset(widget.options.length) + widget.selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToMiddleSegment();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _centerSelected(animated: false);
        });
      });
      return;
    }
    if (_normalizeIndex(_loopIndex, widget.options.length) !=
        widget.selectedIndex) {
      _loopIndex = _baseOffset(widget.options.length) + widget.selectedIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _centerSelected(animated: true);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _centerSelected({required bool animated}) {
    if (!mounted) {
      return;
    }
    if (_loopIndex < 0 || _loopIndex >= _itemKeys.length) {
      return;
    }
    final itemContext = _itemKeys[_loopIndex].currentContext;
    final scrollContext = _scrollKey.currentContext;
    if (itemContext == null || scrollContext == null) {
      return;
    }
    if (animated) {
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.5,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    } else {
      Scrollable.ensureVisible(
        itemContext,
        alignment: 0.5,
        duration: Duration.zero,
      );
    }
  }

  void _handleSelect(int index) {
    return;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C20),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFF2A2A2E)),
      ),
      child: SizedBox(
        height: 44,
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification is ScrollEndNotification) {
              _snapToMiddleSegment();
            } else if (notification is UserScrollNotification &&
                notification.direction == ScrollDirection.idle) {
              _snapToMiddleSegment();
            }
            return false;
          },
          child: ListView.builder(
            key: _scrollKey,
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.options.length * 3,
            itemBuilder: (context, index) {
              final normalized =
                  _normalizeIndex(index, widget.options.length);
              final isSelected = index == _loopIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: IgnorePointer(
                  key: _itemKeys[index],
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFF59BC4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      widget.options[normalized],
                      style: context.theme.typography.base.copyWith(
                        color: isSelected
                            ? Colors.white
                            : context.theme.colors.mutedForeground,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<GlobalKey> _buildKeys(int length) {
    return List.generate(length * 3, (_) => GlobalKey());
  }

  int _normalizeIndex(int index, int length) {
    if (length == 0) {
      return 0;
    }
    final mod = index % length;
    return mod < 0 ? mod + length : mod;
  }

  int _baseOffset(int length) => length;

  bool _isMiddleSegment(int index, int length) {
    final start = length;
    final end = (length * 2) - 1;
    return index >= start && index <= end;
  }

  void _snapToMiddleSegment() {
    if (!mounted || _itemKeys.isEmpty) {
      return;
    }
    final normalized =
        _normalizeIndex(_loopIndex, widget.options.length);
    _loopIndex = _baseOffset(widget.options.length) + normalized;
    _jumpToMiddleSegment();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerSelected(animated: false);
    });
  }

  void _jumpToMiddleSegment() {
    if (!_scrollController.hasClients || widget.options.isEmpty) {
      return;
    }
    final extent = _itemExtentForIndex(0);
    if (extent <= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _jumpToMiddleSegment();
      });
      return;
    }
    final target = extent * widget.options.length;
    final position = _scrollController.position;
    final clamped = target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _scrollController.jumpTo(clamped);
  }

  double _itemExtentForIndex(int index) {
    if (index < 0 || index >= _itemKeys.length) {
      return 0;
    }
    final context = _itemKeys[index].currentContext;
    final box = context?.findRenderObject() as RenderBox?;
    if (box == null) {
      return 0;
    }
    return box.size.width + 12;
  }

  int? _nearestIndexToCenter() {
    final scrollContext = _scrollKey.currentContext;
    if (scrollContext == null) {
      return null;
    }
    final scrollBox = scrollContext.findRenderObject() as RenderBox?;
    if (scrollBox == null) {
      return null;
    }
    final centerX = scrollBox.size.width / 2;
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var i = 0; i < _itemKeys.length; i++) {
      final itemContext = _itemKeys[i].currentContext;
      if (itemContext == null) {
        continue;
      }
      final itemBox = itemContext.findRenderObject() as RenderBox?;
      if (itemBox == null) {
        continue;
      }
      final itemOffset =
          itemBox.localToGlobal(Offset.zero, ancestor: scrollBox).dx;
      final itemCenter = itemOffset + itemBox.size.width / 2;
      final distance = (itemCenter - centerX).abs();
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }
    return nearestIndex;
  }
}

class _SmileFacePainter extends CustomPainter {
  const _SmileFacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = const Color(0xFF1A1A1A)
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
    canvas.drawArc(
      smileRect,
      0,
      3.14,
      false,
      linePaint,
    );

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
