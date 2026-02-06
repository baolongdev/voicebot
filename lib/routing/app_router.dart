import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../presentation/pages/home_page.dart';
import '../features/form/presentation/pages/server_form_page.dart';
import '../features/chat/presentation/pages/chat_page.dart';
import '../presentation/pages/splash_page.dart';
import '../presentation/pages/mcp_flow_page.dart';
import 'routes.dart';

class AppRouter {
  const AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: Routes.home,
    redirect: (BuildContext context, GoRouterState state) {
      final location = state.matchedLocation;
      if (location == Routes.splash) {
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
        path: Routes.home,
        name: RouteNames.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: Routes.form,
        name: RouteNames.form,
        builder: (context, state) => const ServerFormPage(),
      ),
      GoRoute(
        path: Routes.chat,
        name: RouteNames.chat,
        builder: (context, state) => const ChatPage(),
      ),
      GoRoute(
        path: Routes.mcpFlow,
        name: RouteNames.mcpFlow,
        builder: (context, state) => McpFlowPage(),
      ),
      GoRoute(
        path: Routes.root,
        name: RouteNames.root,
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
}
