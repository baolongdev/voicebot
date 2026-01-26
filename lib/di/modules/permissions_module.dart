import 'package:get_it/get_it.dart';

import '../../core/permissions/permission_service.dart';
import '../../infrastructure/permissions/permission_service_impl.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../system/permissions/permission_state_listenable.dart';

void registerPermissions(GetIt getIt) {
  if (!getIt.isRegistered<PermissionService>()) {
    getIt.registerLazySingleton<PermissionService>(PermissionServiceImpl.new);
  }

  if (!getIt.isRegistered<PermissionCubit>()) {
    getIt.registerLazySingleton<PermissionCubit>(
      () => PermissionCubit(getIt<PermissionService>()),
    );
  }

  if (!getIt.isRegistered<PermissionStateListenable>()) {
    getIt.registerLazySingleton<PermissionStateListenable>(
      () => PermissionStateListenable(getIt<PermissionCubit>()),
    );
  }
}
