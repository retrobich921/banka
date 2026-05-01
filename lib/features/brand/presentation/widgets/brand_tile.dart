import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/brand.dart';

/// Строка списка брендов: лого (или плейсхолдер), имя, страна, счётчик
/// постов. Используется на `BrandsPage` и `BrandPickerSheet`.
class BrandTile extends StatelessWidget {
  const BrandTile({super.key, required this.brand, this.trailing, this.onTap});

  final Brand brand;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _Logo(logoUrl: brand.logoUrl),
      title: Text(
        brand.name.isEmpty ? brand.slug : brand.name,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: brand.country == null || brand.country!.isEmpty
          ? null
          : Text(
              brand.country!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
      trailing:
          trailing ??
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.image_outlined,
                size: 16,
                color: AppColors.onSurfaceFaint,
              ),
              const SizedBox(width: 4),
              Text(
                '${brand.postsCount}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceFaint,
                ),
              ),
            ],
          ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.logoUrl});

  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    if (logoUrl != null && logoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: logoUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (_, _, _) => const _Placeholder(),
        ),
      );
    }
    return const _Placeholder();
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.local_drink_outlined,
        size: 20,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}
