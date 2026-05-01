import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:injectable/injectable.dart';

import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/pages/sign_in_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/brand/presentation/pages/brand_detail_page.dart';
import '../../features/brand/presentation/pages/brands_page.dart';
import '../../features/group/presentation/bloc/groups_list_bloc.dart';
import '../../features/group/presentation/pages/create_group_page.dart';
import '../../features/group/presentation/pages/group_detail_page.dart';
import '../../features/group/presentation/pages/groups_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/like/presentation/pages/who_liked_page.dart';
import '../../features/post/presentation/pages/create_post_page.dart';
import '../../features/post/presentation/pages/post_detail_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/user/presentation/bloc/profile_bloc.dart';
import '../../features/user/presentation/pages/edit_profile_page.dart';
import '../../features/user/presentation/pages/profile_page.dart';
import '../di/injector.dart';
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
      GoRoute(
        path: AppRoutes.postCreate,
        name: AppRoutes.postCreateName,
        builder: (_, state) {
          final extra = state.extra;
          if (extra is Map) {
            return CreatePostPage(
              groupId: extra['groupId'] as String?,
              groupName: extra['groupName'] as String?,
            );
          }
          return const CreatePostPage();
        },
      ),
      GoRoute(
        path: AppRoutes.postDetail,
        name: AppRoutes.postDetailName,
        builder: (_, state) =>
            PostDetailPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.whoLiked,
        name: AppRoutes.whoLikedName,
        builder: (_, state) =>
            WhoLikedPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.search,
        name: AppRoutes.searchName,
        builder: (_, _) => const SearchPage(),
      ),
      GoRoute(
        path: AppRoutes.brands,
        name: AppRoutes.brandsName,
        builder: (_, _) => const BrandsPage(),
        routes: [
          GoRoute(
            path: ':id',
            name: AppRoutes.brandDetailName,
            builder: (_, state) =>
                BrandDetailPage(brandId: state.pathParameters['id']!),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider<ProfileBloc>(
          create: (_) => sl<ProfileBloc>(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.profile,
            name: AppRoutes.profileName,
            builder: (_, _) => const ProfilePage(),
          ),
          GoRoute(
            path: AppRoutes.profileEdit,
            name: AppRoutes.profileEditName,
            builder: (_, _) => const EditProfilePage(),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => BlocProvider<GroupsListBloc>(
          create: (_) => sl<GroupsListBloc>(),
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.groups,
            name: AppRoutes.groupsName,
            builder: (_, _) => const GroupsPage(),
            routes: [
              GoRoute(
                path: 'new',
                name: AppRoutes.groupCreateName,
                builder: (_, _) => const CreateGroupPage(),
              ),
              GoRoute(
                path: ':id',
                name: AppRoutes.groupDetailName,
                builder: (_, state) =>
                    GroupDetailPage(groupId: state.pathParameters['id']!),
              ),
            ],
          ),
        ],
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
