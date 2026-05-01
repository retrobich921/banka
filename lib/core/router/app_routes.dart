/// Централизованные имена и пути маршрутов приложения.
///
/// Используем абстрактный финальный класс со статическими константами вместо
/// `enum`, чтобы было удобно ссылаться: `context.goNamed(AppRoutes.signInName)`.
abstract final class AppRoutes {
  // Paths
  static const String splash = '/';
  static const String signIn = '/sign-in';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String profileEdit = '/profile/edit';

  // Names (используем при навигации `goNamed` / `pushNamed`).
  static const String splashName = 'splash';
  static const String signInName = 'signIn';
  static const String homeName = 'home';
  static const String profileName = 'profile';
  static const String profileEditName = 'profileEdit';
}
