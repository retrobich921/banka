import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/brands_bloc.dart';
import '../widgets/brand_tile.dart';

/// Список брендов в порядке `postsCount desc, name asc`.
///
/// Тап по карточке → `BrandDetailPage`.
class BrandsPage extends StatelessWidget {
  const BrandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BrandsBloc>(
      create: (_) => sl<BrandsBloc>()..add(const BrandsSubscribeRequested()),
      child: const _BrandsView(),
    );
  }
}

class _BrandsView extends StatelessWidget {
  const _BrandsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Бренды')),
      body: BlocBuilder<BrandsBloc, BrandsState>(
        builder: (context, state) {
          if (state.isLoading || state.status == BrandsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.hasError) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  state.errorMessage ?? 'Не удалось загрузить бренды',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.error),
                ),
              ),
            );
          }
          if (state.brands.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Пока ни одного бренда.\nПоявятся, как только кто-то запостит банку с указанием бренда.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: state.brands.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.surfaceVariant),
            itemBuilder: (_, i) {
              final brand = state.brands[i];
              return BrandTile(
                brand: brand,
                onTap: () => context.pushNamed(
                  AppRoutes.brandDetailName,
                  pathParameters: {'id': brand.id},
                ),
              );
            },
          );
        },
      ),
    );
  }
}
