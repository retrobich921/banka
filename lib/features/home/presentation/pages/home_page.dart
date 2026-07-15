import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/update/app_updater.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../group/presentation/bloc/groups_list_bloc.dart';
import '../../../group/presentation/pages/groups_page.dart';
import '../../../post/presentation/bloc/posts_feed_bloc.dart';
import '../../../post/presentation/bloc/subscriptions_feed_bloc.dart';
import '../../../post/presentation/widgets/posts_feed_view.dart';
import '../../../post/presentation/widgets/subscriptions_feed_view.dart';
import '../../../tops/presentation/pages/tops_page.dart';
import '../../../user/presentation/bloc/profile_bloc.dart';
import '../../../user/presentation/pages/profile_page.dart';

/// Главный экран с нижней навигацией: Лента (Все / Подписки), Топы,
/// Группы, Профиль. Разделы живут в `IndexedStack`, чтобы не терять
/// состояние (скролл, подписки) при переключении.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Автопроверка обновления на GitHub Releases при заходе на главный экран.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybePromptUpdate(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _tab,
        children: [
          const FeedTab(),
          const TopsPage(),
          BlocProvider<GroupsListBloc>(
            create: (_) => sl<GroupsListBloc>(),
            child: const GroupsPage(),
          ),
          BlocProvider<ProfileBloc>(
            create: (_) => sl<ProfileBloc>(),
            child: const ProfilePage(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Лента',
          ),
          NavigationDestination(
            icon: Icon(Icons.emoji_events_outlined),
            selectedIcon: Icon(Icons.emoji_events),
            label: 'Топы',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Группы',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

/// Вкладка «Лента»: глобальная лента и лента подписок (VK-style).
class FeedTab extends StatelessWidget {
  const FeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.id;
    return MultiBlocProvider(
      providers: [
        BlocProvider<PostsFeedBloc>(
          create: (_) => sl<PostsFeedBloc>()
            ..add(const PostsFeedSubscribeRequested(PostsFeedScope.global())),
        ),
        BlocProvider<SubscriptionsFeedBloc>(
          create: (_) {
            final bloc = sl<SubscriptionsFeedBloc>();
            if (userId != null) bloc.add(SubscriptionsFeedRequested(userId));
            return bloc;
          },
        ),
      ],
      child: FeedTabView(userId: userId),
    );
  }
}

/// View-слой вкладки «Лента». Вынесен публично, чтобы виджет-тест мог
/// обернуть его собственными BlocProvider'ами без инициализации DI.
@visibleForTesting
class FeedTabView extends StatelessWidget {
  const FeedTabView({super.key, this.userId});

  final String? userId;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
              tooltip: 'Бренды',
              icon: const Icon(Icons.local_drink_outlined),
              onPressed: () => context.pushNamed(AppRoutes.brandsName),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Все'),
              Tab(text: 'Подписки'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const PostsFeedView(
              emptyText:
                  'Пока никто не запостил банку.\n'
                  'Будь первым — нажми «Запостить банку».',
            ),
            if (userId != null)
              SubscriptionsFeedView(userId: userId!)
            else
              const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
