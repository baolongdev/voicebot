import 'package:voicebot/core/permissions/permission_status.dart';
import 'package:voicebot/core/permissions/permission_type.dart';

enum PermissionFlowStatus {
  initial,
  checking,
  requesting,
  ready,
  denied,
}

class PermissionState {
  static const List<PermissionType> requiredPermissions = <PermissionType>[
    PermissionType.microphone,
  ];

  const PermissionState({
    required this.status,
    required this.statuses,
  });

  factory PermissionState.initial() {
    return const PermissionState(
      status: PermissionFlowStatus.initial,
      statuses: <PermissionType, PermissionStatus>{},
    );
  }

  final PermissionFlowStatus status;
  final Map<PermissionType, PermissionStatus> statuses;

  bool get isChecking =>
      status == PermissionFlowStatus.initial ||
      status == PermissionFlowStatus.checking ||
      status == PermissionFlowStatus.requesting;

  bool get isReady => requiredPermissions.every(
        (type) => statuses[type] == PermissionStatus.granted,
      );

  PermissionState copyWith({
    PermissionFlowStatus? status,
    Map<PermissionType, PermissionStatus>? statuses,
  }) {
    return PermissionState(
      status: status ?? this.status,
      statuses: statuses ?? this.statuses,
    );
  }
}
