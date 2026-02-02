class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String home = '/home';
  static const String form = '/form';
  static const String chat = '/chat';
  static const String root = '/';
}

class RouteNames {
  const RouteNames._();

  static const String splash = 'splash';
  static const String home = 'home';
  static const String form = 'form';
  static const String chat = 'chat';
  static const String root = 'root';
}

class RouteMeta {
  const RouteMeta._();

  static const Set<String> publicRoutes = <String>{
    Routes.splash,
    Routes.form,
  };

  static const Set<String> protectedRoutes = <String>{
    Routes.home,
  };

  static bool requiresAuth(String location) {
    return protectedRoutes.contains(location);
  }

  static bool isAuthRoute(String location) {
    return false;
  }
}
