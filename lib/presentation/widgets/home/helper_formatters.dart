import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

import '../../../features/home/domain/entities/home_system_status.dart';

String formatDate(DateTime now) =>
    '${_two(now.day)}/${_two(now.month)}/${now.year}';

String formatTime(DateTime now) => '${_two(now.hour)}:${_two(now.minute)}';

String? cleanWifiName(String? name) {
  if (name == null) {
    return null;
  }
  final trimmed = name.trim();
  if (trimmed.isEmpty || trimmed == '<unknown ssid>') {
    return null;
  }
  if (trimmed.length >= 2 && trimmed.startsWith('"') && trimmed.endsWith('"')) {
    return trimmed.substring(1, trimmed.length - 1);
  }
  return trimmed;
}

String networkDisplay(
  List<HomeConnectivity>? results,
  String? wifiName,
  String? carrierName,
) {
  if (results == null || results.isEmpty) {
    return '--';
  }
  if (results.contains(HomeConnectivity.wifi)) {
    final name = cleanWifiName(wifiName);
    return name ?? 'Wi‑Fi';
  }
  if (results.contains(HomeConnectivity.mobile)) {
    return carrierName ?? 'Mobile';
  }
  if (results.contains(HomeConnectivity.ethernet)) {
    return 'Ethernet';
  }
  return 'Offline';
}

bool isOffline(List<HomeConnectivity>? results) {
  if (results == null || results.isEmpty) {
    return true;
  }
  if (results.contains(HomeConnectivity.none)) {
    return true;
  }
  return false;
}

IconData wifiIcon(List<HomeConnectivity>? results, String? wifiName) {
  if (results == null || results.isEmpty) {
    return FIcons.wifiOff;
  }
  if (results.contains(HomeConnectivity.wifi)) {
    final hasName = cleanWifiName(wifiName) != null;
    return hasName ? FIcons.wifiHigh : FIcons.wifiLow;
  }
  if (results.contains(HomeConnectivity.mobile)) {
    return FIcons.cardSim;
  }
  if (results.contains(HomeConnectivity.ethernet)) {
    return FIcons.wifiHigh;
  }
  return FIcons.wifiOff;
}

String batteryText(int? level) {
  final percent = level == null ? '--' : '$level%';
  return percent;
}

IconData batteryIcon(int? level, HomeBatteryState? state) {
  if (state == HomeBatteryState.charging) {
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

String volumeText(double? volume) {
  if (volume == null) {
    return '--%';
  }
  return '${(volume * 100).round()}%';
}

IconData audioIcon(double? volume) {
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

IconData? routeIcon(HomeAudioDevice? device) {
  if (device == null) {
    return null;
  }
  switch (device.route) {
    case HomeAudioRoute.bluetooth:
      return FIcons.bluetoothSearching;
    case HomeAudioRoute.speaker:
      return FIcons.speaker;
    case HomeAudioRoute.other:
    case HomeAudioRoute.wired:
      return null;
  }
}

IconData wifiSignalIcon(int level) {
  if (level < -70) {
    return FIcons.wifiLow;
  }
  return FIcons.wifiHigh;
}

String normalizeTranscript(String text) {
  return text.replaceAll(RegExp(r'\n{2,}'), '\n').trimRight();
}

List<TextSpan> highlightNumbers(
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

List<TextSpan> highlightTranscriptTokens(
  String text,
  TextStyle baseStyle,
  TextStyle numberStyle,
  TextStyle braceStyle,
) {
  final spans = <TextSpan>[];
  final regex = RegExp(r'\*\*[^*]+\*\*|\{[^}]+\}');
  var index = 0;
  for (final match in regex.allMatches(text)) {
    if (match.start > index) {
      spans.addAll(
        highlightNumbers(
          text.substring(index, match.start),
          baseStyle,
          numberStyle,
        ),
      );
    }
    var segment = text.substring(match.start, match.end);
    if (segment.startsWith('**') && segment.endsWith('**')) {
      segment = segment.substring(2, segment.length - 2);
    }
    final boldNumberStyle =
        numberStyle.copyWith(fontWeight: braceStyle.fontWeight);
    spans.addAll(
      highlightNumbers(
        segment,
        braceStyle,
        boldNumberStyle,
      ),
    );
    index = match.end;
  }
  if (index < text.length) {
    spans.addAll(highlightNumbers(text.substring(index), baseStyle, numberStyle));
  }
  return spans;
}

String _two(int value) => value.toString().padLeft(2, '0');
