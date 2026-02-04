enum HomeBatteryState {
  charging,
  discharging,
  full,
  unknown,
}

enum HomeConnectivity {
  wifi,
  mobile,
  ethernet,
  bluetooth,
  vpn,
  other,
  none,
}

enum HomeAudioRoute {
  bluetooth,
  speaker,
  wired,
  other,
}

class HomeAudioDevice {
  const HomeAudioDevice({
    required this.route,
    this.name,
  });

  final HomeAudioRoute route;
  final String? name;
}
