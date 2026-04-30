import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import 'app_routes.dart';

/// Конфигурация навигации с auth-aware редиректом.
///
/// Логика redirect:
/// - splash остаётся видимым, пока `AuthBloc` в `AuthStatus.initial` (т.е. до
///   первого emit'а из `authStateChanges`).
/// - Если пользователь не залогинен — отправляем на `/sign-in`.
/// - Если залогинен — отправляем на `/home`.
/// - Изменение состояния `AuthBloc` триггерит `refreshListenable` → router
///   пересчитывает redirect.
@lazySingleton
final class AppRouter {
  AppRouter(this._authBloc);

  final AuthBloc _authBloc;

  late final GoRouter config = GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: _AuthBlocListenable(_authBloc),
    redirect: _redirect,
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

  String? _redirect(BuildContext context, GoRouterState state) {
    final AuthStatus status = _authBloc.state.status;
    final String location = state.matchedLocation;

    // Пока не получили первый emit от authStateChanges — держим на splash.
    if (status == AuthStatus.initial) {
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    }

    final bool loggedIn = status == AuthStatus.authenticated;
    final bool atSplash = location == AppRoutes.splash;
    final bool atSignIn = location == AppRoutes.signIn;

    if (!loggedIn && !atSignIn) return AppRoutes.signIn;
    if (loggedIn && (atSplash || atSignIn)) return AppRoutes.home;
    return null;
  }
}

/// Адаптер `AuthBloc` → `Listenable` для `GoRouter.refreshListenable`.
class _AuthBlocListenable extends ChangeNotifier {
  _AuthBlocListenable(this._bloc) {
    _subscription = _bloc.stream.listen((_) => notifyListeners());
  }

  final AuthBloc _bloc;
  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
