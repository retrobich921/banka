import 'dart:async';

import 'package:banka/core/error/failures.dart';
import 'package:banka/core/usecases/usecase.dart';
import 'package:banka/features/auth/domain/entities/auth_user.dart';
import 'package:banka/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:banka/features/auth/domain/usecases/sign_out.dart';
import 'package:banka/features/auth/domain/usecases/watch_auth_state.dart';
import 'package:banka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchAuthState extends Mock implements WatchAuthState {}

class _MockSignInWithGoogle extends Mock implements SignInWithGoogle {}

class _MockSignOut extends Mock implements SignOut {}

void main() {
  late _MockWatchAuthState watchAuthState;
  late _MockSignInWithGoogle signInWithGoogle;
  late _MockSignOut signOut;

  const testUser = AuthUser(
    id: 'uid-1',
    email: 'test@example.com',
    displayName: 'Test User',
  );

  setUpAll(() {
    registerFallbackValue(const NoParams());
  });

  setUp(() {
    watchAuthState = _MockWatchAuthState();
    signInWithGoogle = _MockSignInWithGoogle();
    signOut = _MockSignOut();
  });

  AuthBloc build() => AuthBloc(watchAuthState, signInWithGoogle, signOut);

  group('AuthStarted', () {
    blocTest<AuthBloc, AuthState>(
      'emits authenticated when stream yields a user',
      setUp: () {
        when(
          () => watchAuthState(any()),
        ).thenAnswer((_) => Stream<AuthUser?>.value(testUser));
      },
      build: build,
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: const Duration(milliseconds: 50),
      expect: () => const [AuthState.authenticated(testUser)],
    );

    blocTest<AuthBloc, AuthState>(
      'emits unauthenticated when stream yields null',
      setUp: () {
        when(
          () => watchAuthState(any()),
        ).thenAnswer((_) => Stream<AuthUser?>.value(null));
      },
      build: build,
      act: (bloc) => bloc.add(const AuthStarted()),
      wait: const Duration(milliseconds: 50),
      expect: () => const [AuthState.unauthenticated()],
    );
  });

  group('AuthGoogleSignInRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits signingIn then nothing on success (auth-state stream pushes user)',
      setUp: () {
        when(
          () => watchAuthState(any()),
        ).thenAnswer((_) => const Stream<AuthUser?>.empty());
        when(
          () => signInWithGoogle(any()),
        ).thenAnswer((_) async => const Right(testUser));
      },
      build: build,
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => const [AuthState.signingIn()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits signingIn then error on failure',
      setUp: () {
        when(
          () => watchAuthState(any()),
        ).thenAnswer((_) => const Stream<AuthUser?>.empty());
        when(() => signInWithGoogle(any())).thenAnswer(
          (_) async => const Left(AuthFailure(message: 'cancelled')),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const AuthGoogleSignInRequested()),
      expect: () => const [AuthState.signingIn(), AuthState.error('cancelled')],
    );
  });

  group('AuthSignOutRequested', () {
    blocTest<AuthBloc, AuthState>(
      'emits nothing on success (auth-state stream emits null next)',
      setUp: () {
        when(
          () => watchAuthState(any()),
        ).thenAnswer((_) => const Stream<AuthUser?>.empty());
        when(() => signOut(any())).thenAnswer((_) async => const Right(null));
      },
      build: build,
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => const <AuthState>[],
    );

    blocTest<AuthBloc, AuthState>(
      'emits error on failure',
      setUp: () {
        when(
          () => watchAuthState(any()),
        ).thenAnswer((_) => const Stream<AuthUser?>.empty());
        when(() => signOut(any())).thenAnswer(
          (_) async => const Left(AuthFailure(message: 'no network')),
        );
      },
      build: build,
      act: (bloc) => bloc.add(const AuthSignOutRequested()),
      expect: () => const [AuthState.error('no network')],
    );
  });

  test('cancels stream subscription on close', () async {
    final controller = StreamController<AuthUser?>();
    when(() => watchAuthState(any())).thenAnswer((_) => controller.stream);

    final bloc = build();
    bloc.add(const AuthStarted());
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await bloc.close();

    expect(controller.hasListener, isFalse);
    await controller.close();
  });
}
