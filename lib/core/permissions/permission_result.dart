import 'permission_status.dart';
import 'permission_type.dart';

class PermissionResult {
  const PermissionResult({
    required this.type,
    required this.status,
  });

  final PermissionType type;
  final PermissionStatus status;
}
