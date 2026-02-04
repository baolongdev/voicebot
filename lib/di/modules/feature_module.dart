import 'package:get_it/get_it.dart';

import '../../core/system/ota/ota_service.dart' as core_ota;
import '../../features/chat/application/state/chat_cubit.dart';
import '../../features/chat/application/usecases/connect_chat_usecase.dart';
import '../../features/chat/application/usecases/disconnect_chat_usecase.dart';
import '../../features/chat/application/usecases/load_chat_config_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_errors_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_incoming_level_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_outgoing_level_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_responses_usecase.dart';
import '../../features/chat/application/usecases/observe_chat_speaking_usecase.dart';
import '../../features/chat/application/usecases/send_audio_frame_usecase.dart';
import '../../features/chat/application/usecases/send_chat_message_usecase.dart';
import '../../features/chat/application/usecases/set_listening_mode_usecase.dart';
import '../../features/chat/application/usecases/start_listening_usecase.dart';
import '../../features/chat/application/usecases/stop_listening_usecase.dart';
import '../../features/chat/domain/repositories/chat_config_provider.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/infrastructure/repositories/chat_config_provider_impl.dart';
import '../../features/chat/infrastructure/repositories/chat_repository_impl.dart';
import '../../features/form/infrastructure/repositories/settings_repository.dart';
import '../../features/home/application/state/home_cubit.dart';
import '../../features/home/domain/services/home_system_service.dart';
import '../../features/home/infrastructure/services/home_system_service_impl.dart';
import '../../capabilities/voice/default_session_coordinator.dart';
import '../../capabilities/voice/session_coordinator.dart';
import '../../capabilities/voice/voice_platform_factory.dart';

void registerChatFeature(GetIt getIt) {
  if (!getIt.isRegistered<ChatRepository>()) {
    getIt.registerLazySingleton<ChatRepository>(
      () => ChatRepositoryImpl(
        sessionCoordinator: getIt<SessionCoordinator>(),
      ),
    );
  }

  if (!getIt.isRegistered<SessionCoordinator>()) {
    getIt.registerLazySingleton<SessionCoordinator>(
      () => DefaultSessionCoordinator(
        audioInput: VoicePlatformFactory.createAudioInput(),
        audioOutput: VoicePlatformFactory.createAudioOutput(),
      ),
    );
  }

  if (!getIt.isRegistered<ChatConfigProvider>()) {
    getIt.registerLazySingleton<ChatConfigProvider>(
      () => ChatConfigProviderImpl(
        settings: getIt<SettingsRepository>(),
        ota: getIt<core_ota.OtaService>(),
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

  if (!getIt.isRegistered<StopListeningUseCase>()) {
    getIt.registerFactory<StopListeningUseCase>(
      () => StopListeningUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<SetListeningModeUseCase>()) {
    getIt.registerFactory<SetListeningModeUseCase>(
      () => SetListeningModeUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatResponsesUseCase>()) {
    getIt.registerFactory<ObserveChatResponsesUseCase>(
      () => ObserveChatResponsesUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatErrorsUseCase>()) {
    getIt.registerFactory<ObserveChatErrorsUseCase>(
      () => ObserveChatErrorsUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatIncomingLevelUseCase>()) {
    getIt.registerFactory<ObserveChatIncomingLevelUseCase>(
      () => ObserveChatIncomingLevelUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatOutgoingLevelUseCase>()) {
    getIt.registerFactory<ObserveChatOutgoingLevelUseCase>(
      () => ObserveChatOutgoingLevelUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ObserveChatSpeakingUseCase>()) {
    getIt.registerFactory<ObserveChatSpeakingUseCase>(
      () => ObserveChatSpeakingUseCase(getIt<ChatRepository>()),
    );
  }

  if (!getIt.isRegistered<ChatCubit>()) {
    getIt.registerLazySingleton<ChatCubit>(
      () => ChatCubit(
        loadConfig: getIt<LoadChatConfigUseCase>(),
        connect: getIt<ConnectChatUseCase>(),
        disconnect: getIt<DisconnectChatUseCase>(),
        sendMessage: getIt<SendChatMessageUseCase>(),
        startListening: getIt<StartListeningUseCase>(),
        stopListening: getIt<StopListeningUseCase>(),
        setListeningMode: getIt<SetListeningModeUseCase>(),
        observeResponses: getIt<ObserveChatResponsesUseCase>(),
        observeErrors: getIt<ObserveChatErrorsUseCase>(),
        observeIncomingLevel: getIt<ObserveChatIncomingLevelUseCase>(),
        observeOutgoingLevel: getIt<ObserveChatOutgoingLevelUseCase>(),
        observeSpeaking: getIt<ObserveChatSpeakingUseCase>(),
      ),
    );
  }
}

void registerHomeFeature(GetIt getIt) {
  if (!getIt.isRegistered<HomeSystemService>()) {
    getIt.registerLazySingleton<HomeSystemService>(
      HomeSystemServiceImpl.new,
    );
  }
  if (!getIt.isRegistered<HomeCubit>()) {
    getIt.registerLazySingleton<HomeCubit>(
      () => HomeCubit(
        settingsRepository: getIt<SettingsRepository>(),
        ota: getIt<core_ota.OtaService>(),
        chatCubit: getIt<ChatCubit>(),
        systemService: getIt<HomeSystemService>(),
      ),
    );
  }
}
