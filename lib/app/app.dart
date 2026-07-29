import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injector.dart';
import '../core/notifications/push_notifications_service.dart';
import '../core/router/app_router.dart';
import '../core/router/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

/// Корневой виджет. Поднимает глобальный `AuthBloc` через `BlocProvider`,
/// после чего отдаёт `MaterialApp.router` с тёмной темой и go_router'ом.
class BankaApp extends StatefulWidget {
  const BankaApp({super.key});

  @override
  State<BankaApp> createState() => _BankaAppState();
}

class _BankaAppState extends State<BankaApp> {
  late final AuthBloc _authBloc;
  late final AppRouter _router;
  late final PushNotificationsService _push;

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(const AuthStarted());
    _router = sl<AppRouter>();
    _push = sl<PushNotificationsService>()
      ..onOpenPost = (postId) => _router.config.pushNamed(
        AppRoutes.postDetailName,
        pathParameters: {'id': postId},
      );
  }

  @override
  void dispose() {
    _authBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>.value(
      value: _authBloc,
      child: BlocListener<AuthBloc, AuthState>(
        // Токен устройства привязываем к пользователю сразу после логина.
        listenWhen: (prev, curr) => prev.user?.id != curr.user?.id,
        listener: (context, state) {
          final userId = state.user?.id;
          if (userId != null) _push.registerFor(userId);
        },
        child: MaterialApp.router(
          title: 'banka',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.dark,
          routerConfig: _router.config,
        ),
      ),
    );
  }
}
