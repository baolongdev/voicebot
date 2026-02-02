import 'package:flutter_test/flutter_test.dart';

import 'package:voicebot/core/permissions/permission_status.dart';
import 'package:voicebot/core/permissions/permission_type.dart';
import 'package:voicebot/system/permissions/permission_state.dart';

void main() {
  group('PermissionState.isReady', () {
    test('true when all required permissions are granted', () {
      final statuses = <PermissionType, PermissionStatus>{
        for (final type in PermissionState.requiredPermissions)
          type: PermissionStatus.granted,
      };

      final state = PermissionState(
        status: PermissionFlowStatus.ready,
        statuses: statuses,
      );

      expect(state.isReady, isTrue);
    });

    test('false when any required permission is missing or denied', () {
      final statuses = <PermissionType, PermissionStatus>{
        for (final type in PermissionState.requiredPermissions)
          type: PermissionStatus.granted,
      };
      statuses[PermissionType.microphone] = PermissionStatus.denied;

      final state = PermissionState(
        status: PermissionFlowStatus.denied,
        statuses: statuses,
      );

      expect(state.isReady, isFalse);
    });
  });
}
