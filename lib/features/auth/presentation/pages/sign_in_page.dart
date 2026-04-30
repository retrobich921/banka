import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';

/// Заглушка экрана входа.
///
/// Sprint 1 — только UI-скелет с дизайном (тёмная тема, акцент-кнопка).
/// В Sprint 2 кнопка получит `BlocProvider<AuthBloc>` и реальный
/// `SignInWithGoogle` usecase. Сейчас просто переходит на Home.
class SignInPage extends StatelessWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              const Icon(
                Icons.local_drink_outlined,
                size: 72,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              Text(
                'banka',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Каталог и сообщество коллекционеров энергетиков',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
              const Spacer(flex: 3),
              ElevatedButton.icon(
                onPressed: () => context.goNamed(AppRoutes.homeName),
                icon: const Icon(Icons.login),
                label: const Text('Войти через Google'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
