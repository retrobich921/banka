import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../post/presentation/bloc/posts_feed_bloc.dart';
import '../../../post/presentation/widgets/posts_feed_view.dart';
import '../../domain/entities/brand.dart';
import '../../domain/usecases/watch_brand.dart';

/// Страница бренда: шапка с лого/именем/счётчиком + лента постов
/// бренда (отсортирована по `rarity desc` через `WatchBrandFeed`).
class BrandDetailPage extends StatelessWidget {
  const BrandDetailPage({super.key, required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<PostsFeedBloc>(
          create: (_) => sl<PostsFeedBloc>()
            ..add(PostsFeedSubscribeRequested(PostsFeedScope.brand(brandId))),
        ),
      ],
      child: _BrandDetailView(brandId: brandId),
    );
  }
}

class _BrandDetailView extends StatelessWidget {
  const _BrandDetailView({required this.brandId});

  final String brandId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<Either<Failure, Brand?>>(
        stream: sl<WatchBrand>().call(brandId),
        builder: (context, snapshot) {
          final result = snapshot.data;
          final brand = result?.fold((_) => null, (b) => b);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 200,
                backgroundColor: AppColors.background,
                title: Text(brand?.name ?? 'Бренд'),
                flexibleSpace: brand == null
                    ? null
                    : FlexibleSpaceBar(background: _Header(brand: brand)),
              ),
              const SliverFillRemaining(
                hasScrollBody: true,
                child: PostsFeedView(
                  emptyText: 'У этого бренда пока нет постов.',
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.brand});

  final Brand brand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 80, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (brand.logoUrl != null && brand.logoUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: brand.logoUrl!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => _placeholder(),
              ),
            )
          else
            _placeholder(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(brand.name, style: theme.textTheme.titleLarge),
                if (brand.country != null && brand.country!.isNotEmpty)
                  Text(
                    brand.country!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${brand.postsCount} постов',
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

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.local_drink_outlined,
        size: 32,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}
