import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/forui/forui_theme.dart';
import '../../di/locator.dart';
import '../../features/chat/application/state/chat_cubit.dart';
import '../../features/home/application/state/home_cubit.dart';
import '../../presentation/app/listening_mode_cubit.dart';
import '../../presentation/app/carousel_settings_cubit.dart';
import '../../presentation/app/text_send_mode_cubit.dart';
import '../../presentation/app/connect_greeting_cubit.dart';
import '../../presentation/app/auto_reconnect_cubit.dart';
import '../../presentation/app/face_detection_settings_cubit.dart';
import '../../presentation/app/device_mac_cubit.dart';
import '../../presentation/app/theme_mode_cubit.dart';
import '../../presentation/app/theme_palette_cubit.dart';
import '../../presentation/app/text_scale_cubit.dart';
import '../../presentation/app/update_cubit.dart';
import '../../system/permissions/permission_notifier.dart';
import '../../theme/theme_palette.dart';

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  @override
  void initState() {
    super.initState();
    if (AppConfig.permissionsEnabled) {
      // Checking is safe at startup; requests stay behind explicit user action.
      getIt<PermissionCubit>().checkRequiredPermissions();
    }
    getIt<ThemeModeCubit>().hydrate();
    getIt<ThemePaletteCubit>().hydrate();
    getIt<TextScaleCubit>().hydrate();
    getIt<ListeningModeCubit>().hydrate();
    getIt<TextSendModeCubit>().hydrate();
    getIt<ConnectGreetingCubit>().hydrate();
    getIt<AutoReconnectCubit>().hydrate();
    getIt<CarouselSettingsCubit>().hydrate();
    getIt<FaceDetectionSettingsCubit>().hydrate();
    getIt<DeviceMacCubit>().hydrate();
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = getIt<GoRouter>();

    return MultiBlocProvider(
      providers: [
        BlocProvider<ThemeModeCubit>.value(value: getIt<ThemeModeCubit>()),
        BlocProvider<ThemePaletteCubit>.value(
          value: getIt<ThemePaletteCubit>(),
        ),
        BlocProvider<TextScaleCubit>.value(value: getIt<TextScaleCubit>()),
        BlocProvider<ListeningModeCubit>.value(
          value: getIt<ListeningModeCubit>(),
        ),
        BlocProvider<TextSendModeCubit>.value(
          value: getIt<TextSendModeCubit>(),
        ),
        BlocProvider<ConnectGreetingCubit>.value(
          value: getIt<ConnectGreetingCubit>(),
        ),
        BlocProvider<AutoReconnectCubit>.value(
          value: getIt<AutoReconnectCubit>(),
        ),
        BlocProvider<CarouselSettingsCubit>.value(
          value: getIt<CarouselSettingsCubit>(),
        ),
        BlocProvider<FaceDetectionSettingsCubit>.value(
          value: getIt<FaceDetectionSettingsCubit>(),
        ),
        BlocProvider<DeviceMacCubit>.value(value: getIt<DeviceMacCubit>()),
        BlocProvider<PermissionCubit>.value(value: getIt<PermissionCubit>()),
        BlocProvider<ChatCubit>.value(value: getIt<ChatCubit>()),
        BlocProvider<HomeCubit>.value(value: getIt<HomeCubit>()),
        BlocProvider<UpdateCubit>.value(value: getIt<UpdateCubit>()),
      ],
      child: BlocBuilder<ThemePaletteCubit, AppThemePalette>(
        builder: (context, palette) {
          final lightTheme = AppForuiTheme.light(palette);
          final darkTheme = AppForuiTheme.dark(palette);
          return BlocBuilder<ThemeModeCubit, ThemeMode>(
            builder: (context, themeMode) {
              return BlocBuilder<TextScaleCubit, double>(
                builder: (context, textScale) {
                  return MaterialApp.router(
                    routerConfig: router,
                    theme: lightTheme.toApproximateMaterialTheme(),
                    darkTheme: darkTheme.toApproximateMaterialTheme(),
                    themeMode: themeMode,
                    localizationsDelegates:
                        FLocalizations.localizationsDelegates,
                    supportedLocales: FLocalizations.supportedLocales,
                    builder: (context, child) {
                      final brightness = _resolveBrightness(context, themeMode);
                      final theme = AppForuiTheme.themeForBrightness(
                        brightness,
                        palette,
                      );
                      final mediaQuery = MediaQuery.of(context);
                      final iconSize = 24 * textScale;

                      return MediaQuery(
                        data: mediaQuery.copyWith(
                          textScaler: TextScaler.linear(textScale),
                        ),
                        child: IconTheme(
                          data: IconThemeData(size: iconSize),
                          child: FAnimatedTheme(
                            data: theme,
                            child: WillPopScope(
                              onWillPop: () async =>
                                  defaultTargetPlatform != TargetPlatform.android,
                              child: child ?? const SizedBox.shrink(),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Brightness _resolveBrightness(BuildContext context, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Brightness.dark;
      case ThemeMode.light:
        return Brightness.light;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context);
    }
  }
}
