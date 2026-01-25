import 'permission_result.dart';
import 'permission_type.dart';

abstract class PermissionService {
  Future<PermissionResult> check(PermissionType type);

  Future<PermissionResult> request(PermissionType type);

  Future<List<PermissionResult>> requestMultiple(List<PermissionType> types);
}
