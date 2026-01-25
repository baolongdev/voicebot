import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:http/http.dart' as http;

import '../../core/config/api_config.dart';
import '../../core/system/ota/ota.dart' as core_ota;
import '../../features/auth/application/usecases/check_auth.usecase.dart';
import '../../features/auth/application/usecases/login.usecase.dart';
import '../../features/auth/application/usecases/logout.usecase.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/infrastructure/datasources/auth_local_ds.dart';
import '../../features/auth/infrastructure/datasources/auth_remote_ds.dart';
import '../../features/auth/infrastructure/mappers/user_mapper.dart';
import '../../features/auth/infrastructure/repositories/auth_repository_impl.dart';
import '../../features/auth/presentation/state/auth_bloc.dart';
import '../../features/auth/presentation/state/auth_state_listenable.dart';
import '../../features/chat/application/state/chat_controller.dart';
import '../../features/chat/application/usecases/connect_chat_usecase.dart';
import '../../features/chat/application/usecases/disconnect_chat_usecase.dart';
import '../../features/chat/application/usecases/get_server_sample_rate_usecase.dart';
import '../../features/chat/application/usecases/load_chat_config_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_audio_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_errors_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_responses_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_speaking_usecase.dart';
import '../../features/chat/application/usecases/send_audio_frame_usecase.dart';
import '../../features/chat/application/usecases/send_chat_message_usecase.dart';
import '../../features/chat/application/usecases/start_listening_usecase.dart';
import '../../features/chat/domain/repositories/chat_config_provider.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/infrastructure/repositories/chat_config_provider_impl.dart';
import '../../features/chat/infrastructure/repositories/chat_repository_impl.dart';
import '../../features/form/infrastructure/repositories/settings_repository.dart';

void registerAuthFeature(GetIt getIt) {
  if (!getIt.isRegistered<http.Client>()) {
    getIt.registerLazySingleton<http.Client>(http.Client.new);
  }

  if (!getIt.isRegistered<FlutterSecureStorage>()) {
    getIt.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );
  }

  if (!getIt.isRegistered<UserMapper>()) {
    getIt.registerLazySingleton<UserMapper>(() => const UserMapper());
  }

  if (!getIt.isRegistered<AuthRemoteDataSource>()) {
    getIt.registerLazySingleton<AuthRemoteDataSource>(
      () => AuthRemoteDataSourceImpl(
        client: getIt<http.Client>(),
        baseUrl: ApiConfig.baseUrl,
      ),
    );
  }

  if (!getIt.isRegistered<AuthLocalDataSource>()) {
    getIt.registerLazySingleton<AuthLocalDataSource>(
      () => AuthLocalDataSourceImpl(getIt<FlutterSecureStorage>()),
    );
  }

  if (!getIt.isRegistered<AuthRepository>()) {
    getIt.registerLazySingleton<AuthRepository>(
      () => AuthRepositoryImpl(
        remote: getIt<AuthRemoteDataSource>(),
        local: getIt<AuthLocalDataSource>(),
        mapper: getIt<UserMapper>(),
      ),
    );
  }

  if (!getIt.isRegistered<LoginUseCase>()) {
    getIt.registerFactory<LoginUseCase>(
      () => LoginUseCase(getIt<AuthRepository>()),
    );
  }

  if (!getIt.isRegistered<LogoutUseCase>()) {
    getIt.registerFactory<LogoutUseCase>(
      () => LogoutUseCase(getIt<AuthRepository>()),
    );
  }

  if (!getIt.isRegistered<CheckAuthUseCase>()) {
    getIt.registerFactory<CheckAuthUseCase>(
      () => CheckAuthUseCase(getIt<AuthRepository>()),
    );
  }

  if (!getIt.isRegistered<AuthBloc>()) {
    getIt.registerLazySingleton<AuthBloc>(
      () => AuthBloc(
        login: getIt<LoginUseCase>(),
        logout: getIt<LogoutUseCase>(),
        checkAuth: getIt<CheckAuthUseCase>(),
      ),
    );
  }

  if (!getIt.isRegistered<AuthStateListenable>()) {
    getIt.registerLazySingleton<AuthStateListenable>(
      () => AuthStateListenable(getIt<AuthBloc>()),
    );
  }
}

void registerChatFeature(GetIt getIt) {
  if (!getIt.isRegistered<ChatRepository>()) {
    getIt.registerLazySingleton<ChatRepository>(ChatRepositoryImpl.new);
  }

  if (!getIt.isRegistered<ChatConfigProvider>()) {
    getIt.registerLazySingleton<ChatConfigProvider>(
      () => ChatConfigProviderImpl(
        settings: getIt<SettingsRepository>(),
        ota: getIt<core_ota.Ota>(),
      ),
    );
  }

  if (!getIt.isRegistered<LoadChatConfigUseCase>()) {
    getIt.registerFactory<LoadChatConfigUseCase>(
      () => LoadChatConfigUseCase(getIt<ChatConfigProvider>()),
    );
  }

  if (!getIt.isRegistered<ConnectChatUseCase>()) {
    getIt.registerFactory<ConnectChatUseCase>(
      () => ConnectChatUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<DisconnectChatUseCase>()) {
    getIt.registerFactory<DisconnectChatUseCase>(
      () => DisconnectChatUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<GetServerSampleRateUseCase>()) {
    getIt.registerFactory<GetServerSampleRateUseCase>(
      () => GetServerSampleRateUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<SendChatMessageUseCase>()) {
    getIt.registerFactory<SendChatMessageUseCase>(
      () => SendChatMessageUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<SendAudioFrameUseCase>()) {
    getIt.registerFactory<SendAudioFrameUseCase>(
      () => SendAudioFrameUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<StartListeningUseCase>()) {
    getIt.registerFactory<StartListeningUseCase>(
      () => StartListeningUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatResponsesUseCase>()) {
    getIt.registerFactory<ObserveChatResponsesUseCase>(
      () => ObserveChatResponsesUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatAudioUseCase>()) {
    getIt.registerFactory<ObserveChatAudioUseCase>(
      () => ObserveChatAudioUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatErrorsUseCase>()) {
    getIt.registerFactory<ObserveChatErrorsUseCase>(
      () => ObserveChatErrorsUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatSpeakingUseCase>()) {
    getIt.registerFactory<ObserveChatSpeakingUseCase>(
      () => ObserveChatSpeakingUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ChatController>()) {
    getIt.registerFactory<ChatController>(
      () => ChatController(
        loadConfig: getIt<LoadChatConfigUseCase>(),
        connect: getIt<ConnectChatUseCase>(),
        disconnect: getIt<DisconnectChatUseCase>(),
        getServerSampleRate: getIt<GetServerSampleRateUseCase>(),
        sendMessage: getIt<SendChatMessageUseCase>(),
        sendAudioFrame: getIt<SendAudioFrameUseCase>(),
        startListening: getIt<StartListeningUseCase>(),
        observeResponses: getIt<ObserveChatResponsesUseCase>(),
        observeAudio: getIt<ObserveChatAudioUseCase>(),
        observeErrors: getIt<ObserveChatErrorsUseCase>(),
        observeSpeaking: getIt<ObserveChatSpeakingUseCase>(),
      ),
    );
  }
}
