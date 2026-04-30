import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/di/injector.dart';
import '../core/router/app_router.dart';
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

  @override
  void initState() {
    super.initState();
    _authBloc = sl<AuthBloc>()..add(const AuthStarted());
    _router = sl<AppRouter>();
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
      child: MaterialApp.router(
        title: 'banka',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: _router.config,
      ),
    );
  }
}
