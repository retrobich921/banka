part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => const [];
}

/// Подписаться на стрим Firebase auth-state. Диспатчится один раз при создании
/// блока (в `AppBootstrap`).
final class AuthStarted extends AuthEvent {
  const AuthStarted();
}

/// Внутреннее событие, прокидывается из стрима auth-state. UI его не вызывает.
final class _AuthUserChanged extends AuthEvent {
  const _AuthUserChanged(this.user);

  final AuthUser? user;

  @override
  List<Object?> get props => [user];
}

/// UI: пользователь нажал «Войти через Google».
final class AuthGoogleSignInRequested extends AuthEvent {
  const AuthGoogleSignInRequested();
}

/// UI: пользователь нажал «Выйти».
final class AuthSignOutRequested extends AuthEvent {
  const AuthSignOutRequested();
}
