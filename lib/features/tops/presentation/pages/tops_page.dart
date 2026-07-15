import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/domain/entities/post_ranking.dart';
import '../../../post/domain/usecases/top_posts.dart';
import '../../../post/presentation/widgets/rating_widgets.dart';
import '../../../user/domain/entities/user_profile.dart';
import '../../../user/domain/usecases/top_collectors.dart';

/// Раздел «Топы» — рейтинги: лучшие банки (по оценке), популярные (по
/// лайкам), топ коллекционеров и топ брендов.
class TopsPage extends StatelessWidget {
  const TopsPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Вкладки «Бренды» здесь нет намеренно — каталог брендов доступен
    // с главного экрана (иконка в AppBar ленты).
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Топы'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '🏆 Лучшие'),
              Tab(text: '❤️ Популярные'),
              Tab(text: '👤 Коллекционеры'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _TopPostsTab(ranking: PostRanking.topRated),
            _TopPostsTab(ranking: PostRanking.mostLiked),
            _TopCollectorsTab(),
          ],
        ),
      ),
    );
  }
}

// ============================== Посты ==============================

class _TopPostsTab extends StatefulWidget {
  const _TopPostsTab({required this.ranking});

  final PostRanking ranking;

  @override
  State<_TopPostsTab> createState() => _TopPostsTabState();
}

class _TopPostsTabState extends State<_TopPostsTab> {
  late final Future<Either<Failure, List<Post>>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<TopPosts>()(TopPostsParams(ranking: widget.ranking));
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncList<Post>(
      future: _future,
      emptyText: widget.ranking == PostRanking.topRated
          ? 'Пока никто не оценил банки.'
          : 'Пока нет лайков.',
      itemBuilder: (context, i, post) =>
          _TopPostTile(rank: i + 1, post: post, ranking: widget.ranking),
    );
  }
}

class _TopPostTile extends StatelessWidget {
  const _TopPostTile({
    required this.rank,
    required this.post,
    required this.ranking,
  });

  final int rank;
  final Post post;
  final PostRanking ranking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumb = post.photos.isNotEmpty
        ? (post.photos.first.thumbUrl.isNotEmpty
              ? post.photos.first.thumbUrl
              : post.photos.first.url)
        : null;
    return ListTile(
      onTap: () => context.pushNamed(
        AppRoutes.postDetailName,
        pathParameters: {'id': post.id},
      ),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RankBadge(rank: rank),
          const SizedBox(width: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: thumb == null
                ? const _ThumbPlaceholder()
                : CachedNetworkImage(
                    imageUrl: thumb,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => const _ThumbPlaceholder(),
                  ),
          ),
        ],
      ),
      title: Text(
        post.drinkName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        post.brandName?.isNotEmpty == true
            ? post.brandName!
            : post.drinkType.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.onSurfaceMuted,
        ),
      ),
      trailing: ranking == PostRanking.topRated && post.rating != null
          ? RatingScoreBadge(score: post.rating!.score, compact: true)
          : _LikePill(count: post.likesCount),
    );
  }
}

class _LikePill extends StatelessWidget {
  const _LikePill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.favorite, size: 16, color: AppColors.primary),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ========================== Коллекционеры ==========================

class _TopCollectorsTab extends StatefulWidget {
  const _TopCollectorsTab();

  @override
  State<_TopCollectorsTab> createState() => _TopCollectorsTabState();
}

class _TopCollectorsTabState extends State<_TopCollectorsTab> {
  late final Future<Either<Failure, List<UserProfile>>> _future;

  @override
  void initState() {
    super.initState();
    _future = sl<TopCollectors>()();
  }

  @override
  Widget build(BuildContext context) {
    return _AsyncList<UserProfile>(
      future: _future,
      emptyText: 'Пока нет коллекционеров.',
      itemBuilder: (context, i, user) {
        final theme = Theme.of(context);
        return ListTile(
          onTap: () => context.pushNamed(
            AppRoutes.userProfileName,
            pathParameters: {'id': user.id},
          ),
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RankBadge(rank: i + 1),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceVariant,
                backgroundImage:
                    (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                    ? CachedNetworkImageProvider(user.photoUrl!)
                    : null,
                child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                    ? const Icon(Icons.person_outline, size: 20)
                    : null,
              ),
            ],
          ),
          title: Text(
            user.displayName.isEmpty ? 'Коллекционер' : user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          trailing: Text(
            '${user.stats.cansCount} банок',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      },
    );
  }
}

// ============================== Общее ==============================

/// Список из одноразового `Future<Either<Failure, List<T>>>` с состояниями
/// загрузки / ошибки / пустоты.
class _AsyncList<T> extends StatelessWidget {
  const _AsyncList({
    required this.future,
    required this.emptyText,
    required this.itemBuilder,
  });

  final Future<Either<Failure, List<T>>> future;
  final String emptyText;
  final Widget Function(BuildContext context, int index, T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<Failure, List<T>>>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snapshot.data!.fold((_) => <T>[], (list) => list);
        if (items.isEmpty) return _CenteredHint(text: emptyText);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: items.length,
          itemBuilder: (context, i) => itemBuilder(context, i, items[i]),
        );
      },
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  Color get _color => switch (rank) {
    1 => const Color(0xFFFFD700), // золото
    2 => const Color(0xFFC0C0C0), // серебро
    3 => const Color(0xFFCD7F32), // бронза
    _ => AppColors.surfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final top3 = rank <= 3;
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
      child: Text(
        '$rank',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          color: top3 ? Colors.black : AppColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      color: AppColors.surfaceVariant,
      child: const Icon(
        Icons.local_drink_outlined,
        size: 20,
        color: AppColors.onSurfaceMuted,
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
        padding: const EdgeInsets.all(24),
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
