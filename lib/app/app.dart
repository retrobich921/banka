import 'package:flutter/material.dart';

import '../core/di/injector.dart';
import '../core/router/app_router.dart';
import '../core/theme/app_theme.dart';

/// Корневой виджет. `MaterialApp.router` со связкой go_router + тёмная тема.
class BankaApp extends StatefulWidget {
  const BankaApp({super.key});

  @override
  State<BankaApp> createState() => _BankaAppState();
}

class _BankaAppState extends State<BankaApp> {
  late final AppRouter _router;

  @override
  void initState() {
    super.initState();
    _router = sl<AppRouter>();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'banka',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: _router.config,
    );
  }
}
