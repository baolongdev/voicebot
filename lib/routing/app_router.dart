import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../core/config/app_config.dart';
import '../di/locator.dart';
import '../features/auth/presentation/pages/auth_page.dart';
import '../features/auth/presentation/state/auth_state_listenable.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/form/presentation/pages/server_form_page.dart';
import '../features/activation/presentation/pages/activation_page.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../system/permissions/permission_request_view.dart';
import '../system/permissions/permission_state_listenable.dart';
import '../presentation/pages/splash_page.dart';
import '../presentation/pages/v2_home_page.dart';
import '../presentation/pages/v2_permissions_page.dart';
import 'routes.dart';

class AppRouter {
  const AppRouter._();

  static final GoRouter router = GoRouter(
    // Keep auth routes intact; short-circuit via config during UI development.
    initialLocation: AppConfig.useNewFlow
        ? Routes.v2Home
        : (AppConfig.authEnabled ? Routes.splash : Routes.home),
    refreshListenable: Listenable.merge(<Listenable>[
      getIt<AuthStateListenable>(),
      getIt<PermissionStateListenable>(),
    ]),
    redirect: (BuildContext context, GoRouterState state) {
      if (AppConfig.permissionsEnabled) {
        final permissionState = getIt<PermissionStateListenable>();
        final location = state.matchedLocation;
        final isV2Route = location.startsWith('/v2');
        final isV2Permissions = location == Routes.v2Permissions;
        if (AppConfig.useNewFlow && isV2Route) {
          return null;
        }
        if (!permissionState.isChecking &&
            !permissionState.isReady &&
            location != Routes.permissions &&
            !isV2Permissions) {
          return AppConfig.useNewFlow ? Routes.v2Permissions : Routes.permissions;
        }
        if (permissionState.isReady && location == Routes.permissions) {
          return Routes.home;
        }
      }
      if (!AppConfig.authEnabled) {
        return null;
      }
      final authState = getIt<AuthStateListenable>();
      final location = state.matchedLocation;

      if (authState.isCheckingAuth) {
        return null;
      }

      final isAuthenticated = authState.isAuthenticated;

      if (location == Routes.splash) {
        return isAuthenticated ? Routes.home : Routes.auth;
      }

      final requiresAuth = RouteMeta.requiresAuth(location);
      final isAuthRoute = RouteMeta.isAuthRoute(location);

      if (!isAuthenticated && requiresAuth) {
        return Routes.auth;
      }

      if (isAuthenticated && isAuthRoute) {
        return Routes.home;
      }

      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.splash,
        name: RouteNames.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: Routes.permissions,
        name: RouteNames.permissions,
        builder: (context, state) => const PermissionRequestView(),
      ),
      GoRoute(
        path: Routes.v2Permissions,
        name: RouteNames.v2Permissions,
        builder: (context, state) => const V2PermissionsPage(),
      ),
      GoRoute(
        path: Routes.auth,
        name: RouteNames.auth,
        builder: (context, state) => const AuthPage(),
      ),
      GoRoute(
        path: Routes.home,
        name: RouteNames.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.v2Home,
        name: RouteNames.v2Home,
        builder: (context, state) => const V2HomePage(),
      ),
      GoRoute(
        path: Routes.form,
        name: RouteNames.form,
        builder: (context, state) => const ServerFormPage(),
      ),
      GoRoute(
        path: Routes.activation,
        name: RouteNames.activation,
        builder: (context, state) => const ActivationPage(),
      ),
      GoRoute(
        path: Routes.chat,
        name: RouteNames.chat,
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: Routes.root,
        name: RouteNames.root,
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}
