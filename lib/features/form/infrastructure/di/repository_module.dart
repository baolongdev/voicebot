import 'package:get_it/get_it.dart';

import 'package:voicebot/core/system/ota/ota.dart';
import '../../domain/repositories/form_repository.dart';
import '../repositories/form_repository_impl.dart';
import '../repositories/settings_repository.dart';
import '../repositories/settings_repository_impl.dart';

// Ported from Android Kotlin: RepositoryModule.kt
void registerRepositoryModule(GetIt getIt) {
  if (!getIt.isRegistered<SettingsRepository>()) {
    getIt.registerLazySingleton<SettingsRepository>(SettingsRepositoryImpl.new);
  }

  if (!getIt.isRegistered<FormRepository>()) {
    getIt.registerLazySingleton<FormRepository>(
      () => FormRepositoryImpl(
        ota: getIt<Ota>(),
        settingsRepository: getIt<SettingsRepository>(),
      ),
    );
  }
}
