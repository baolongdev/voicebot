class HomeWifiNetwork {
  const HomeWifiNetwork({
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
