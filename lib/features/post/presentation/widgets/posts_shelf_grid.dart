import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/post.dart';

/// «Полка» — сетка квадратных превью банок (3 в ряд), как галерея
/// коллекции. Тап по банке открывает детальный экран поста.
class PostsShelfSliver extends StatelessWidget {
  const PostsShelfSliver({super.key, required this.posts});

  final List<Post> posts;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: posts.length,
        itemBuilder: (context, i) => _ShelfTile(post: posts[i]),
      ),
    );
  }
}

class _ShelfTile extends StatelessWidget {
  const _ShelfTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final photo = post.photos.isNotEmpty ? post.photos.first : null;
    final thumb = photo == null
        ? null
        : (photo.thumbUrl.isNotEmpty ? photo.thumbUrl : photo.url);
    return InkWell(
      onTap: () => context.pushNamed(
        AppRoutes.postDetailName,
        pathParameters: {'id': post.id},
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb == null)
              const ColoredBox(
                color: AppColors.surfaceVariant,
                child: Icon(
                  Icons.local_drink_outlined,
                  color: AppColors.onSurfaceMuted,
                ),
              )
            else
              CachedNetworkImage(
                imageUrl: thumb,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: AppColors.surfaceVariant),
                errorWidget: (_, _, _) => const ColoredBox(
                  color: AppColors.surfaceVariant,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.onSurfaceFaint,
                  ),
                ),
              ),
            if (post.photos.length > 1)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(
                  Icons.collections_outlined,
                  size: 16,
                  color: Colors.white,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Переключатель вида коллекции: полка (сетка) ↔ лента (карточки).
class ShelfViewToggle extends StatelessWidget {
  const ShelfViewToggle({
    super.key,
    required this.shelf,
    required this.onChanged,
  });

  /// true — полка (сетка), false — лента.
  final bool shelf;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToggleIcon(
          icon: Icons.grid_view_rounded,
          tooltip: 'Полка',
          selected: shelf,
          onTap: () => onChanged(true),
        ),
        const SizedBox(width: 4),
        _ToggleIcon(
          icon: Icons.view_agenda_outlined,
          tooltip: 'Лента',
          selected: !shelf,
          onTap: () => onChanged(false),
        ),
      ],
    );
  }
}

class _ToggleIcon extends StatelessWidget {
  const _ToggleIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      icon: Icon(
        icon,
        size: 20,
        color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
      ),
      onPressed: onTap,
    );
  }
}
