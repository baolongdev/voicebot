import 'package:uuid/uuid.dart';

class UuidHelper {
  UuidHelper._();

  static const _uuid = Uuid();

  static String generateV4() => _uuid.v4();

  static String generateV4Short() => _uuid.v4().split('-').first;

  static String generateDeviceId() {
    final uuid = _uuid.v4();
    return uuid.replaceAll('-', '').toLowerCase();
  }

  static bool isValidUuid(String? uuid) {
    if (uuid == null) return false;
    final regex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return regex.hasMatch(uuid);
  }
}
