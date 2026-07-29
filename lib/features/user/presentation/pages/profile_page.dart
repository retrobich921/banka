import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/notifications/push_notifications_service.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../post/presentation/bloc/posts_feed_bloc.dart';
import '../../../post/presentation/pages/post_detail_page.dart';
import '../../../post/presentation/widgets/collapsible_item.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../post/presentation/widgets/posts_shelf_grid.dart';
import '../../domain/entities/user_profile.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/achievements_row.dart';
import '../widgets/profile_stats_row.dart';

/// Экран профиля текущего пользователя.
///
/// При входе на экран подписывается на документ `users/{uid}` через
/// `ProfileBloc` (если профиля ещё нет — `EnsureUserDocument` создаёт его) и
/// на ленту собственных банок через `PostsFeedBloc` в author-скоупе.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  void initState() {
    super.initState();
    _subscribeProfile();
  }

  void _subscribeProfile() {
    final authState = context.read<AuthBloc>().state;
    if (authState.user != null) {
      context.read<ProfileBloc>().add(
        ProfileSubscribeRequested(authState.user!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.id;
    return BlocProvider<PostsFeedBloc>(
      create: (_) {
        final bloc = sl<PostsFeedBloc>();
        if (userId != null) {
          bloc.add(PostsFeedSubscribeRequested(PostsFeedScope.author(userId)));
        }
        return bloc;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Профиль'),
          actions: [
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: 'Архив',
              onPressed: () => context.pushNamed(AppRoutes.archiveName),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Редактировать',
              onPressed: () => context.pushNamed(AppRoutes.profileEditName),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Выйти',
              onPressed: () async {
                // Токен отвязываем до logout: после него запись в
                // `users/{uid}` запрещена правилами, и пуши продолжили бы
                // приходить на это устройство.
                await sl<PushNotificationsService>().unregister();
                if (!context.mounted) return;
                context.read<AuthBloc>().add(const AuthSignOutRequested());
              },
            ),
          ],
        ),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.status == ProfileStatus.error) {
              return _ErrorView(message: state.errorMessage);
            }
            final profile = state.profile;
            if (profile == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return _ProfileContent(profile: profile);
          },
        ),
      ),
    );
  }
}

/// Шапка профиля + лента собственных банок («Мои банки»).
///
/// Используем единый `CustomScrollView`, чтобы шапка и список скроллились
/// вместе, а у списка работала догрузка следующих страниц.
class _ProfileContent extends StatefulWidget {
  const _ProfileContent({required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<_ProfileContent> {
  // Полка (сетка) — вид коллекции по умолчанию.
  bool _shelf = true;

  /// Посты, которые «схлопываются» после архивации.
  final Set<String> _collapsing = <String>{};

  @override
  Widget build(BuildContext context) {
    final feedState = context.watch<PostsFeedBloc>().state;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 400 &&
            !feedState.isLoadingMore &&
            !feedState.hasReachedEnd) {
          context.read<PostsFeedBloc>().add(const PostsFeedLoadMoreRequested());
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(profile: widget.profile)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AchievementsRow(
                cansCount: widget.profile.stats.cansCount,
                pinnedIds: widget.profile.pinnedAchievements,
                onOpen: () => context.pushNamed(AppRoutes.achievementsName),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Моя полка',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ShelfViewToggle(
                    shelf: _shelf,
                    onChanged: (v) => setState(() => _shelf = v),
                  ),
                ],
              ),
            ),
          ),
          ..._buildBanks(context, feedState),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }

  List<Widget> _buildBanks(BuildContext context, PostsFeedState state) {
    if (state.isLoading && state.posts.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (state.status == PostsFeedStatus.error) {
      return [
        SliverToBoxAdapter(
          child: _CenteredHint(
            text: state.errorMessage ?? 'Не удалось загрузить банки',
          ),
        ),
      ];
    }
    if (state.posts.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: _CenteredHint(
            text:
                'Вы ещё не добавили ни одной банки.\nНажмите «+», '
                'чтобы добавить первую.',
          ),
        ),
      ];
    }

    final posts = state.posts;
    if (_shelf) {
      return [
        PostsShelfSliver(
          posts: posts,
          onArchived: (postId) =>
              context.read<PostsFeedBloc>().add(PostsFeedPostHidden(postId)),
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ];
    }

    final itemCount = posts.length + (state.isLoadingMore ? 1 : 0);
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
        sliver: SliverList.separated(
          itemCount: itemCount,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            if (i >= posts.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final post = posts[i];
            return CollapsibleItem(
              key: ValueKey('collapsible-${post.id}'),
              collapsed: _collapsing.contains(post.id),
              onCollapsed: () {
                context.read<PostsFeedBloc>().add(PostsFeedPostHidden(post.id));
                _collapsing.remove(post.id);
              },
              child: PostCard(
                key: ValueKey(post.id),
                post: post,
                onTap: () async {
                  final result = await context.pushNamed<Object?>(
                    AppRoutes.postDetailName,
                    pathParameters: {'id': post.id},
                  );
                  if (result == kPostArchivedResult && mounted) {
                    setState(() => _collapsing.add(post.id));
                  }
                },
              ),
            );
          },
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          _Avatar(photoUrl: profile.photoUrl),
          const SizedBox(height: 16),
          Text(
            profile.displayName.isEmpty ? 'Коллекционер' : profile.displayName,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            profile.email,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
            textAlign: TextAlign.center,
          ),
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.bio!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          ProfileStatsRow(
            userId: profile.id,
            cansCount: profile.stats.cansCount,
            isSelf: true,
          ),
        ],
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 48,
        backgroundImage: NetworkImage(photoUrl!),
        backgroundColor: AppColors.surfaceVariant,
      );
    }
    return const CircleAvatar(
      radius: 48,
      backgroundColor: AppColors.surfaceVariant,
      child: Icon(
        Icons.account_circle_outlined,
        size: 72,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 12),
          Text(
            message ?? 'Неизвестная ошибка',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
