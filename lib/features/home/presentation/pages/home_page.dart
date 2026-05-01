import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('banka'),
        actions: [
          IconButton(
            tooltip: 'Группы',
            icon: const Icon(Icons.groups_outlined),
            onPressed: () => context.pushNamed(AppRoutes.groupsName),
          ),
          IconButton(
            tooltip: 'Мой профиль',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.pushNamed(AppRoutes.profileName),
          ),
          IconButton(
            tooltip: 'Выйти',
            icon: const Icon(Icons.logout),
            onPressed: () =>
                context.read<AuthBloc>().add(const AuthSignOutRequested()),
          ),
        ],
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (prev, curr) => prev.user != curr.user,
        builder: (context, state) {
          final user = state.user;
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (user?.photoUrl != null)
                    CircleAvatar(
                      radius: 36,
                      backgroundImage: NetworkImage(user!.photoUrl!),
                    )
                  else
                    const Icon(
                      Icons.account_circle_outlined,
                      size: 72,
                      color: AppColors.onSurfaceMuted,
                    ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? user?.email ?? 'Гость',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  const Icon(
                    Icons.construction_outlined,
                    size: 40,
                    color: AppColors.onSurfaceFaint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Лента появится в Sprint 9',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AppBar: 👥 группы · 👤 профиль · ⎋ выход.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
