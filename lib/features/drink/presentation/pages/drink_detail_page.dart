import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../post/presentation/widgets/rating_widgets.dart';
import '../../domain/entities/drink.dart';
import '../../domain/usecases/drink_usecases.dart';

/// Карточка напитка (РЗТ-стиль «релиза»): агрегированная оценка
/// сообщества, где покупают (% по магазинам), цены и все посты-рецензии.
class DrinkDetailPage extends StatefulWidget {
  const DrinkDetailPage({super.key, required this.drinkId});

  final String drinkId;

  @override
  State<DrinkDetailPage> createState() => _DrinkDetailPageState();
}

class _DrinkDetailPageState extends State<DrinkDetailPage> {
  List<Post>? _posts;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts() async {
    final result = await sl<FetchDrinkPosts>()(widget.drinkId);
    if (!mounted) return;
    setState(
      () => _posts = result.fold((_) => const <Post>[], (posts) => posts),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Напиток')),
      body: StreamBuilder<Either<Failure, Drink?>>(
        stream: sl<WatchDrink>().call(widget.drinkId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final drink = snapshot.data!.fold<Drink?>((_) => null, (d) => d);
          if (drink == null) {
            return const _CenteredHint(
              text:
                  'Карточка напитка не найдена.\n'
                  'Она появится после первого поста об этом напитке.',
            );
          }
          return RefreshIndicator(
            onRefresh: _loadPosts,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 32),
              children: [
                _DrinkHeader(drink: drink),
                if (drink.stores.isNotEmpty) _StoresBlock(drink: drink),
                _PricesBlock(drink: drink, posts: _posts),
                const Divider(color: AppColors.outline, height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Рецензии коллекционеров',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildPosts(context),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPosts(BuildContext context) {
    final posts = _posts;
    if (posts == null) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (posts.isEmpty) {
      return const [_CenteredHint(text: 'Постов об этом напитке пока нет.')];
    }
    return [
      for (final post in posts)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: PostCard(
            post: post,
            onTap: () => context.pushNamed(
              AppRoutes.postDetailName,
              pathParameters: {'id': post.id},
            ),
            onAuthorTap: () => context.pushNamed(
              AppRoutes.userProfileName,
              pathParameters: {'id': post.authorId},
            ),
          ),
        ),
    ];
  }
}

class _DrinkHeader extends StatelessWidget {
  const _DrinkHeader({required this.drink});

  final Drink drink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 96,
              height: 96,
              child: (drink.thumbUrl == null || drink.thumbUrl!.isEmpty)
                  ? const ColoredBox(
                      color: AppColors.surfaceVariant,
                      child: Icon(
                        Icons.local_drink_outlined,
                        color: AppColors.onSurfaceMuted,
                      ),
                    )
                  : CachedNetworkImage(
                      imageUrl: drink.thumbUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, _) =>
                          const ColoredBox(color: AppColors.surfaceVariant),
                      errorWidget: (_, _, _) =>
                          const ColoredBox(color: AppColors.surfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drink.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (drink.brandName?.isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    drink.brandName!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    if (drink.ratingAvg != null) ...[
                      RatingScoreBadge(score: drink.ratingAvg!.round()),
                      const SizedBox(width: 8),
                      Text(
                        '${drink.ratingCount} '
                        '${_plural(drink.ratingCount, "оценка", "оценки", "оценок")}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                    ] else
                      Text(
                        'Пока без оценок',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${drink.postsCount} '
                  '${_plural(drink.postsCount, "пост", "поста", "постов")}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceFaint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// «Где покупают»: полоски с процентами по магазинам.
class _StoresBlock extends StatelessWidget {
  const _StoresBlock({required this.drink});

  final Drink drink;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = drink.stores.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Где покупают',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final e in entries.take(5)) ...[
            Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: e.value / total,
                      minHeight: 8,
                      backgroundColor: AppColors.surfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${(e.value / total * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// Цены: средняя из агрегата + разброс по загруженным постам.
class _PricesBlock extends StatelessWidget {
  const _PricesBlock({required this.drink, required this.posts});

  final Drink drink;
  final List<Post>? posts;

  @override
  Widget build(BuildContext context) {
    final avg = drink.priceAvg;
    if (avg == null) return const SizedBox.shrink();

    final knownPrices = (posts ?? const <Post>[])
        .map((p) => p.price)
        .whereType<double>()
        .toList();
    String range = '';
    if (knownPrices.length > 1) {
      knownPrices.sort();
      range =
          ' (от ${knownPrices.first.toStringAsFixed(0)} '
          'до ${knownPrices.last.toStringAsFixed(0)} ₽)';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          const Icon(Icons.sell_outlined, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'В среднем ${avg.toStringAsFixed(0)} ₽$range',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

String _plural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
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
