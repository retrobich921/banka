import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../post/presentation/bloc/posts_feed_bloc.dart';
import '../../../post/presentation/widgets/posts_feed_view.dart';

/// Главный экран — глобальная лента «Все банки».
///
/// Отдельный таб «Подписки» появится в Sprint 16 (когда будет логика
/// подписок); таб «Группа» доступен через `GroupDetailPage`.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PostsFeedBloc>(
      create: (_) =>
          sl<PostsFeedBloc>()
            ..add(const PostsFeedSubscribeRequested(PostsFeedScope.global())),
      child: const HomeView(),
    );
  }
}

/// View-слой главного экрана. Вынесен публично, чтобы виджет-тест
/// мог обернуть его собственным `BlocProvider<PostsFeedBloc>` без
/// инициализации DI-контейнера.
@visibleForTesting
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.pushNamed(AppRoutes.postCreateName),
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Запостить банку'),
      ),
      appBar: AppBar(
        title: const Text('banka'),
        actions: [
          IconButton(
            tooltip: 'Поиск',
            icon: const Icon(Icons.search),
            onPressed: () => context.pushNamed(AppRoutes.searchName),
          ),
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
      body: const PostsFeedView(
        emptyText:
            'Пока никто не запостил банку.\nБудь первым — нажми «Запостить банку».',
      ),
    );
  }
}
