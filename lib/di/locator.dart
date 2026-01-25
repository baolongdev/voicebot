import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/system/ota/model/device_info.dart';
import '../core/system/ota/model/ota_result.dart';
import '../core/system/ota/ota.dart' as core_ota;
import '../routing/app_router.dart';
import '../features/form/infrastructure/di/repository_module.dart';
import '../features/form/domain/usecases/submit_form_use_case.dart';
import '../features/form/domain/usecases/validate_form_use_case.dart';
import '../features/form/presentation/state/form_state.dart';
import '../features/form/domain/repositories/form_repository.dart';
import '../system/ota/ota.dart' as system_ota;
import 'modules/feature_module.dart';
import 'modules/permissions_module.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<GoRouter>()) {
    getIt.registerLazySingleton<GoRouter>(() => AppRouter.router);
  }

  if (!getIt.isRegistered<core_ota.Ota>()) {
    getIt.registerLazySingleton<core_ota.Ota>(
      () => _OtaAdapter(system_ota.Ota(DummyDataGenerator.generate())),
    );
  }

  registerAuthFeature(getIt);
  registerRepositoryModule(getIt);
  registerChatFeature(getIt);
  registerPermissions(getIt);

  if (!getIt.isRegistered<SubmitFormUseCase>()) {
    getIt.registerFactory<SubmitFormUseCase>(
      () => SubmitFormUseCase(getIt()),
    );
  }
  if (!getIt.isRegistered<ValidateFormUseCase>()) {
    getIt.registerFactory<ValidateFormUseCase>(ValidateFormUseCase.new);
  }

  if (!getIt.isRegistered<FormBloc>()) {
    getIt.registerFactory<FormBloc>(
      () => FormBloc(
        validateForm: getIt<ValidateFormUseCase>(),
        submitForm: getIt<SubmitFormUseCase>(),
        repository: getIt<FormRepository>(),
      ),
    );
  }
}

class _OtaAdapter implements core_ota.Ota {
  _OtaAdapter(this._delegate);

  final system_ota.Ota _delegate;

  @override
  OtaResult? get otaResult => _delegate.otaResult;

  @override
  DeviceInfo? get deviceInfo => _delegate.deviceInfo;

  @override
  Future<void> checkVersion(String url) async {
    await _delegate.checkVersion(url);
  }
}
