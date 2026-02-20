import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../core/system/ota/model/device_info.dart';
import '../core/system/ota/model/ota_result.dart';
import '../core/system/ota/ota_service.dart' as core_ota;
import '../routing/app_router.dart';
import '../features/form/infrastructure/di/repository_module.dart';
import '../features/form/domain/usecases/submit_form_use_case.dart';
import '../features/form/domain/usecases/validate_form_use_case.dart';
import '../features/form/presentation/state/form_state.dart';
import '../features/form/domain/repositories/form_repository.dart';
import '../presentation/app/listening_mode_cubit.dart';
import '../presentation/app/carousel_settings_cubit.dart';
import '../presentation/app/text_send_mode_cubit.dart';
import '../presentation/app/connect_greeting_cubit.dart';
import '../presentation/app/auto_reconnect_cubit.dart';
import '../presentation/app/face_detection_settings_cubit.dart';
import '../presentation/app/device_mac_cubit.dart';
import '../presentation/app/theme_mode_cubit.dart';
import '../presentation/app/theme_palette_cubit.dart';
import '../presentation/app/text_scale_cubit.dart';
import '../presentation/app/ui_settings_store.dart';
import '../presentation/app/update_cubit.dart';
import '../system/ota/ota_client.dart' as system_ota;
import 'modules/feature_module.dart';
import 'modules/permissions_module.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  if (!getIt.isRegistered<GoRouter>()) {
    getIt.registerLazySingleton<GoRouter>(() => AppRouter.router);
  }

  if (!getIt.isRegistered<FlutterSecureStorage>()) {
    getIt.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );
  }

  if (!getIt.isRegistered<UiSettingsStore>()) {
    getIt.registerLazySingleton<UiSettingsStore>(
      () => UiSettingsStore(getIt<FlutterSecureStorage>()),
    );
  }

  if (!getIt.isRegistered<ThemeModeCubit>()) {
    getIt.registerLazySingleton<ThemeModeCubit>(
      () => ThemeModeCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<ThemePaletteCubit>()) {
    getIt.registerLazySingleton<ThemePaletteCubit>(
      () => ThemePaletteCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<TextScaleCubit>()) {
    getIt.registerLazySingleton<TextScaleCubit>(
      () => TextScaleCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<CarouselSettingsCubit>()) {
    getIt.registerLazySingleton<CarouselSettingsCubit>(
      () => CarouselSettingsCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<ListeningModeCubit>()) {
    getIt.registerLazySingleton<ListeningModeCubit>(
      () => ListeningModeCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<TextSendModeCubit>()) {
    getIt.registerLazySingleton<TextSendModeCubit>(
      () => TextSendModeCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<ConnectGreetingCubit>()) {
    getIt.registerLazySingleton<ConnectGreetingCubit>(
      () => ConnectGreetingCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<AutoReconnectCubit>()) {
    getIt.registerLazySingleton<AutoReconnectCubit>(
      () => AutoReconnectCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<FaceDetectionSettingsCubit>()) {
    getIt.registerLazySingleton<FaceDetectionSettingsCubit>(
      () => FaceDetectionSettingsCubit(getIt<UiSettingsStore>()),
    );
  }

  if (!getIt.isRegistered<DeviceMacCubit>()) {
    getIt.registerLazySingleton<DeviceMacCubit>(
      () => DeviceMacCubit(getIt<UiSettingsStore>(), getIt<core_ota.OtaService>()),
    );
  }

  if (!getIt.isRegistered<UpdateCubit>()) {
    getIt.registerLazySingleton<UpdateCubit>(UpdateCubit.new);
  }

  if (!getIt.isRegistered<core_ota.OtaService>()) {
    getIt.registerLazySingleton<core_ota.OtaService>(
      () => _OtaAdapter(system_ota.OtaClient(DummyDataGenerator.generate())),
    );
  }

  registerRepositoryModule(getIt);
  registerChatFeature(getIt);
  registerHomeFeature(getIt);
  registerPermissions(getIt);

  if (!getIt.isRegistered<SubmitFormUseCase>()) {
    getIt.registerFactory<SubmitFormUseCase>(() => SubmitFormUseCase(getIt()));
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

class _OtaAdapter implements core_ota.OtaService {
  _OtaAdapter(this._delegate);

  final system_ota.OtaClient _delegate;

  @override
  OtaResult? get otaResult => _delegate.otaResult;

  @override
  DeviceInfo? get deviceInfo => _delegate.deviceInfo;

  @override
  Future<void> checkVersion(String url) async {
    await _delegate.checkVersion(url);
  }

  @override
  Future<void> refreshIdentity() async {
    await _delegate.refreshIdentity();
  }
}
