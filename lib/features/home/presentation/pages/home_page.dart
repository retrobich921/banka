import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Заглушка главной страницы. Появится контентом в Sprint 9 (лента).
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('banka')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.construction_outlined,
                size: 48,
                color: AppColors.onSurfaceMuted,
              ),
              const SizedBox(height: 16),
              Text(
                'Лента появится в Sprint 9',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sprint 1 — это скелет приложения: тема, DI, роутер.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
