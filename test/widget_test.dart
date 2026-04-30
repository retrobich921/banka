import 'package:banka/core/theme/app_theme.dart';
import 'package:banka/features/auth/domain/entities/auth_user.dart';
import 'package:banka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:banka/features/auth/presentation/pages/sign_in_page.dart';
import 'package:banka/features/home/presentation/pages/home_page.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthStarted());
    registerFallbackValue(const AuthState.initial());
  });

  Widget makeApp(AuthBloc bloc, Widget page) {
    return MaterialApp(
      theme: AppTheme.dark,
      home: BlocProvider<AuthBloc>.value(value: bloc, child: page),
    );
  }

  testWidgets('SignInPage renders Google button and brand title', (
    tester,
  ) async {
    final bloc = _MockAuthBloc();
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthState.unauthenticated(),
    );

    await tester.pumpWidget(makeApp(bloc, const SignInPage()));
    await tester.pump();

    expect(find.text('banka'), findsOneWidget);
    expect(find.text('Войти через Google'), findsOneWidget);
  });

  testWidgets('SignInPage shows loading state when signing in', (tester) async {
    final bloc = _MockAuthBloc();
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthState.signingIn(),
    );

    await tester.pumpWidget(makeApp(bloc, const SignInPage()));
    await tester.pump();

    expect(find.text('Входим…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('HomePage shows user displayName and sign-out button', (
    tester,
  ) async {
    const user = AuthUser(id: 'uid-1', email: 'a@b.com', displayName: 'Alice');
    final bloc = _MockAuthBloc();
    whenListen(
      bloc,
      const Stream<AuthState>.empty(),
      initialState: const AuthState.authenticated(user),
    );

    await tester.pumpWidget(makeApp(bloc, const HomePage()));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('a@b.com'), findsOneWidget);
    expect(find.byIcon(Icons.logout), findsOneWidget);
  });
}
