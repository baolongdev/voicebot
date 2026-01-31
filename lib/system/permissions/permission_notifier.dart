import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:voicebot/core/permissions/permission_service.dart';
import 'package:voicebot/core/permissions/permission_status.dart';
import 'package:voicebot/core/permissions/permission_type.dart';
import 'package:voicebot/system/permissions/permission_state.dart';

class PermissionCubit extends Cubit<PermissionState> {
  PermissionCubit(this._service) : super(PermissionState.initial());

  final PermissionService _service;

  static final List<PermissionType> requiredPermissions =
      PermissionState.requiredPermissions;

  Future<void> checkRequiredPermissions() async {
    emit(state.copyWith(status: PermissionFlowStatus.checking));
    final statuses = <PermissionType, PermissionStatus>{};
    for (final type in requiredPermissions) {
      final result = await _service.check(type);
      statuses[type] = result.status;
    }
    emit(
      state.copyWith(
        status: _resolveStatus(statuses),
        statuses: statuses,
      ),
    );
  }

  Future<void> requestRequiredPermissions() async {
    emit(state.copyWith(status: PermissionFlowStatus.requesting));
    final results = await _service.requestMultiple(requiredPermissions);
    final statuses = <PermissionType, PermissionStatus>{
      for (final result in results) result.type: result.status,
    };
    emit(
      state.copyWith(
        status: _resolveStatus(statuses),
        statuses: statuses,
      ),
    );
  }

  Future<void> requestPermission(PermissionType type) async {
    emit(state.copyWith(status: PermissionFlowStatus.requesting));
    final result = await _service.request(type);
    final statuses = Map<PermissionType, PermissionStatus>.from(state.statuses);
    statuses[result.type] = result.status;
    emit(
      state.copyWith(
        status: _resolveStatus(statuses),
        statuses: statuses,
      ),
    );
  }

  PermissionFlowStatus _resolveStatus(
    Map<PermissionType, PermissionStatus> statuses,
  ) {
    if (statuses.isEmpty) {
      return PermissionFlowStatus.denied;
    }
    if (statuses.values.every((status) => status == PermissionStatus.granted)) {
      return PermissionFlowStatus.ready;
    }
    return PermissionFlowStatus.denied;
  }
}
