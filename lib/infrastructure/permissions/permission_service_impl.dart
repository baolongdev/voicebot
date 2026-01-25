import 'package:permission_handler/permission_handler.dart' as handler;

import '../../core/permissions/permission_result.dart';
import '../../core/permissions/permission_service.dart';
import '../../core/permissions/permission_status.dart';
import '../../core/permissions/permission_type.dart';

class PermissionServiceImpl implements PermissionService {
  @override
  Future<PermissionResult> check(PermissionType type) async {
    if (type == PermissionType.audio || type == PermissionType.wifi) {
      return PermissionResult(
        type: type,
        status: PermissionStatus.granted,
      );
    }
    final permission = _mapPermission(type);
    final status = await permission.status;
    return PermissionResult(type: type, status: _mapStatus(status));
  }

  @override
  Future<PermissionResult> request(PermissionType type) async {
    if (type == PermissionType.audio || type == PermissionType.wifi) {
      return PermissionResult(
        type: type,
        status: PermissionStatus.granted,
      );
    }
    final permission = _mapPermission(type);
    final status = await permission.request();
    return PermissionResult(type: type, status: _mapStatus(status));
  }

  @override
  Future<List<PermissionResult>> requestMultiple(
    List<PermissionType> types,
  ) async {
    final results = <PermissionResult>[];
    for (final type in types) {
      results.add(await request(type));
    }
    return results;
  }

  handler.Permission _mapPermission(PermissionType type) {
    switch (type) {
      case PermissionType.microphone:
        return handler.Permission.microphone;
      case PermissionType.audio:
        return handler.Permission.microphone;
      case PermissionType.bluetooth:
        return handler.Permission.bluetooth;
      case PermissionType.wifi:
        return handler.Permission.locationWhenInUse;
      case PermissionType.file:
        return handler.Permission.storage;
    }
  }

  PermissionStatus _mapStatus(handler.PermissionStatus status) {
    if (status.isGranted) {
      return PermissionStatus.granted;
    }
    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionStatus.permanentlyDenied;
    }
    return PermissionStatus.denied;
  }
}
