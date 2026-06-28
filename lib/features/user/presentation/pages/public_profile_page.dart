import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../post/presentation/bloc/posts_feed_bloc.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/watch_user.dart';

/// Просмотр профиля другого пользователя (read-only): аватар, имя,
/// @username, био, статистика и лента его банок. Открывается по тапу на
/// автора в карточке/детальном экране поста.
class PublicProfilePage extends StatelessWidget {
  const PublicProfilePage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PostsFeedBloc>(
      create: (_) => sl<PostsFeedBloc>()
        ..add(PostsFeedSubscribeRequested(PostsFeedScope.author(userId))),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Профиль')),
        body: StreamBuilder<Either<Failure, UserProfile?>>(
          stream: sl<WatchUser>().call(userId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final profile = snapshot.data!.fold((_) => null, (p) => p);
            if (profile == null) {
              return const _CenteredHint(text: 'Пользователь не найден');
            }
            return _Content(profile: profile);
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final feedState = context.watch<PostsFeedBloc>().state;

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.pixels >= metrics.maxScrollExtent - 400 &&
            !feedState.isLoadingMore &&
            !feedState.hasReachedEnd) {
          context.read<PostsFeedBloc>().add(
            const PostsFeedLoadMoreRequested(),
          );
        }
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(profile: profile)),
          const SliverToBoxAdapter(child: _SectionTitle('Банки')),
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
    if (state.posts.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: _CenteredHint(text: 'У пользователя пока нет банок.'),
        ),
      ];
    }

    final posts = state.posts;
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
            return PostCard(
              post: posts[i],
              onTap: () => context.pushNamed(
                AppRoutes.postDetailName,
                pathParameters: {'id': posts[i].id},
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
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        children: [
          _Avatar(photoUrl: profile.photoUrl),
          const SizedBox(height: 16),
          Text(
            profile.displayName.isEmpty ? 'Коллекционер' : profile.displayName,
            style: theme.textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          if (profile.username.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '@${profile.username}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              profile.bio!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          _StatsGrid(stats: profile.stats),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _CenteredHint extends StatelessWidget {
  const _CenteredHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceMuted),
        ),
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

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});

  final UserStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatCell(label: 'Банок', value: stats.cansCount.toString()),
        _StatCell(label: 'Лайков', value: stats.likesReceived.toString()),
        _StatCell(label: 'Групп', value: stats.groupsCount.toString()),
        _StatCell(
          label: 'Сред. редкость',
          value: stats.avgRarity.toStringAsFixed(1),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceFaint),
        ),
      ],
    );
  }
}
