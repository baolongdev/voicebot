import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/forui/forui_theme.dart';
import '../../di/locator.dart';
import '../../features/auth/presentation/state/auth_bloc.dart';
import '../../features/auth/presentation/state/auth_event.dart';
import '../../system/permissions/permission_notifier.dart';

class Application extends StatefulWidget {
  const Application({super.key});

  @override
  State<Application> createState() => _ApplicationState();
}

class _ApplicationState extends State<Application> {
  @override
  void initState() {
    super.initState();
    if (AppConfig.authEnabled) {
      getIt<AuthBloc>().add(const AuthStarted());
    }
    if (AppConfig.permissionsEnabled) {
      // Checking is safe at startup; requests stay behind explicit user action.
      getIt<PermissionCubit>().checkRequiredPermissions();
    }
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = getIt<GoRouter>();
    final lightTheme = AppForuiTheme.light();
    final darkTheme = AppForuiTheme.dark();

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: getIt<AuthBloc>()),
        BlocProvider<PermissionCubit>.value(value: getIt<PermissionCubit>()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: lightTheme.toApproximateMaterialTheme(),
        darkTheme: darkTheme.toApproximateMaterialTheme(),
        themeMode: ThemeMode.system,
        localizationsDelegates: FLocalizations.localizationsDelegates,
        supportedLocales: FLocalizations.supportedLocales,
        builder: (context, child) {
          final brightness = MediaQuery.platformBrightnessOf(context);
          final theme = AppForuiTheme.themeForBrightness(brightness);
          final topInset = MediaQuery.paddingOf(context).top;

          return FAnimatedTheme(
            data: theme,
            child: FToaster(
              style: (style) => style.copyWith(
                padding: EdgeInsets.fromLTRB(16, topInset + 24, 16, 16),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
