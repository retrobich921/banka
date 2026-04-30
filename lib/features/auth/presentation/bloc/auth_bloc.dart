import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/usecases/watch_auth_state.dart';

part 'auth_event.dart';
part 'auth_state.dart';

@lazySingleton
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc(this._watchAuthState, this._signInWithGoogle, this._signOut)
    : super(const AuthState.initial()) {
    on<AuthStarted>(_onStarted);
    on<_AuthUserChanged>(_onUserChanged);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
  }

  final WatchAuthState _watchAuthState;
  final SignInWithGoogle _signInWithGoogle;
  final SignOut _signOut;

  StreamSubscription<AuthUser?>? _authSubscription;

  Future<void> _onStarted(AuthStarted event, Emitter<AuthState> emit) async {
    await _authSubscription?.cancel();
    _authSubscription = _watchAuthState(
      const NoParams(),
    ).listen((user) => add(_AuthUserChanged(user)));
  }

  void _onUserChanged(_AuthUserChanged event, Emitter<AuthState> emit) {
    final AuthUser? user = event.user;
    if (user != null) {
      emit(AuthState.authenticated(user));
    } else {
      emit(const AuthState.unauthenticated());
    }
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.signingIn());
    final result = await _signInWithGoogle(const NoParams());
    result.fold(
      (failure) => emit(
        AuthState.error(failure.message ?? 'Не удалось войти через Google'),
      ),
      (_) {
        // Успешный вход прокидывается через authStateChanges → _AuthUserChanged.
      },
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _signOut(const NoParams());
    result.fold(
      (failure) => emit(AuthState.error(failure.message ?? 'Не удалось выйти')),
      (_) {
        // Выход прокидывается через authStateChanges → _AuthUserChanged.
      },
    );
  }

  @override
  Future<void> close() async {
    await _authSubscription?.cancel();
    return super.close();
  }
}
