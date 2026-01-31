class Routes {
  const Routes._();

  static const String splash = '/splash';
  static const String permissions = '/permissions';
  static const String v2Permissions = '/v2/permissions';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String v2Home = '/v2/home';
  static const String form = '/form';
  static const String activation = '/activation';
  static const String chat = '/chat';
  static const String root = '/';
}

class RouteNames {
  const RouteNames._();

  static const String splash = 'splash';
  static const String permissions = 'permissions';
  static const String v2Permissions = 'v2Permissions';
  static const String auth = 'auth';
  static const String home = 'home';
  static const String v2Home = 'v2Home';
  static const String form = 'form';
  static const String activation = 'activation';
  static const String chat = 'chat';
  static const String root = 'root';
}

class RouteMeta {
  const RouteMeta._();

  static const Set<String> publicRoutes = <String>{
    Routes.splash,
    Routes.permissions,
    Routes.v2Permissions,
    Routes.auth,
    Routes.form,
  };

  static const Set<String> protectedRoutes = <String>{
    Routes.home,
    Routes.v2Home,
  };

  static bool requiresAuth(String location) {
    return protectedRoutes.contains(location);
  }

  static bool isAuthRoute(String location) {
    return location == Routes.auth;
  }
}
