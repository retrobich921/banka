/// Имена и пути всех маршрутов приложения. Один источник правды для
/// `go_router` и навигации по имени.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String home = '/home';

  // Имена для context.goNamed / context.pushNamed.
  static const String splashName = 'splash';
  static const String signInName = 'signIn';
  static const String homeName = 'home';
}
