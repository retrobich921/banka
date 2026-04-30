import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import 'app_routes.dart';

/// Конфигурация навигации.
///
/// На старте Sprint 1 редиректы между маршрутами не зависят от состояния auth
/// (его ещё нет). В Sprint 2 здесь появится `redirect:` на основе `AuthBloc`.
@lazySingleton
final class AppRouter {
  AppRouter();

  GoRouter get config => GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        name: AppRoutes.splashName,
        builder: (_, _) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: AppRoutes.signInName,
        builder: (_, _) => const SignInPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        name: AppRoutes.homeName,
        builder: (_, _) => const HomePage(),
      ),
    ],
  );
}
