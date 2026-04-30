part of 'auth_bloc.dart';

enum AuthStatus { initial, authenticated, unauthenticated, signingIn, error }

final class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  /// Стартовое состояние до первого события из watchAuthState.
  const AuthState.initial() : this();

  /// Залогинены.
  const AuthState.authenticated(AuthUser user)
    : this(status: AuthStatus.authenticated, user: user);

  /// Не залогинены (вышли или впервые открыли приложение).
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);

  /// Sign-in в процессе (показываем спиннер вместо кнопки).
  const AuthState.signingIn() : this(status: AuthStatus.signingIn);

  /// Sign-in упал. UI показывает snackbar с `errorMessage`.
  const AuthState.error(String message)
    : this(status: AuthStatus.error, errorMessage: message);

  final AuthStatus status;
  final AuthUser? user;
  final String? errorMessage;

  bool get isAuthenticated =>
      status == AuthStatus.authenticated && user != null;
  bool get isSigningIn => status == AuthStatus.signingIn;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    String? errorMessage,
  }) => AuthState(
    status: status ?? this.status,
    user: user ?? this.user,
    errorMessage: errorMessage ?? this.errorMessage,
  );

  @override
  List<Object?> get props => [status, user, errorMessage];
}
