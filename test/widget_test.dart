import 'package:banka/core/theme/app_theme.dart';
import 'package:banka/features/auth/domain/entities/auth_user.dart';
import 'package:banka/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:banka/features/auth/presentation/pages/sign_in_page.dart';
import 'package:banka/features/home/presentation/pages/home_page.dart';
import 'package:banka/features/post/presentation/bloc/posts_feed_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockPostsFeedBloc extends MockBloc<PostsFeedEvent, PostsFeedState>
    implements PostsFeedBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AuthStarted());
    registerFallbackValue(const AuthState.initial());
    registerFallbackValue(
      const PostsFeedSubscribeRequested(PostsFeedScope.global()),
    );
    registerFallbackValue(const PostsFeedState.initial());
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

  testWidgets(
    'HomeView shows brand title, FAB and sign-out button (empty feed)',
    (tester) async {
      const user = AuthUser(
        id: 'uid-1',
        email: 'a@b.com',
        displayName: 'Alice',
      );
      final auth = _MockAuthBloc();
      whenListen(
        auth,
        const Stream<AuthState>.empty(),
        initialState: const AuthState.authenticated(user),
      );

      final feed = _MockPostsFeedBloc();
      whenListen(
        feed,
        const Stream<PostsFeedState>.empty(),
        initialState: const PostsFeedState(
          status: PostsFeedStatus.ready,
          posts: [],
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<PostsFeedBloc>.value(value: feed),
            ],
            child: const HomeView(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('banka'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.textContaining('Запостить банку'), findsWidgets);
    },
  );
}
