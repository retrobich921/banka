import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../like/presentation/widgets/like_button.dart';
import '../../domain/entities/post.dart';
import 'rarity_badge.dart';

/// Карточка-«банка» в ленте.
///
/// Показывает шапку (аватар автора + имя + дата), карусель фото с
/// `Hero(tag: 'post-photo-{id}')` на первом кадре, заголовок (название
/// напитка), бейдж редкости, опциональный чип группы и теги.
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, required this.onTap});

  final Post post;
  final VoidCallback onTap;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final theme = Theme.of(context);
    final df = DateFormat('d MMM', 'ru_RU');
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _AuthorAvatar(post: post),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.authorName.isNotEmpty
                                ? post.authorName
                                : 'Аноним',
                            style: theme.textTheme.titleSmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (post.foundDate != null)
                            Text(
                              df.format(post.foundDate!),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.onSurfaceMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                    RarityBadge(rarity: post.rarity),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (post.photos.isNotEmpty)
                _PhotoCarousel(
                  post: post,
                  controller: _pageController,
                  currentPage: _currentPage,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: Text(
                  post.drinkName,
                  style: theme.textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if ((post.brandName != null && post.brandName!.isNotEmpty) ||
                  post.groupName != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (post.brandName != null && post.brandName!.isNotEmpty)
                        _Pill(
                          icon: Icons.local_bar_outlined,
                          label: post.brandName!,
                        ),
                      if (post.groupName != null)
                        _Pill(
                          icon: Icons.group_outlined,
                          label: post.groupName!,
                        ),
                    ],
                  ),
                ),
              if (post.tags.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      for (final t in post.tags)
                        Text(
                          '#$t',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 12, 0),
                child: Row(
                  children: [
                    LikeButton(
                      postId: post.id,
                      likesCount: post.likesCount,
                      compact: true,
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.mode_comment_outlined,
                      size: 18,
                      color: AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    if (post.authorPhotoUrl != null && post.authorPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 18,
        backgroundImage: CachedNetworkImageProvider(post.authorPhotoUrl!),
      );
    }
    return const CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.surfaceVariant,
      child: Icon(Icons.person_outline, size: 20),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _PhotoCarousel extends StatelessWidget {
  const _PhotoCarousel({
    required this.post,
    required this.controller,
    required this.currentPage,
    required this.onPageChanged,
  });

  final Post post;
  final PageController controller;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: controller,
            itemCount: post.photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) {
              final photo = post.photos[i];
              final image = CachedNetworkImage(
                imageUrl: photo.thumbUrl.isNotEmpty
                    ? photo.thumbUrl
                    : photo.url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: AppColors.surfaceVariant),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.onSurfaceFaint,
                ),
              );
              if (i == 0) {
                return Hero(tag: 'post-photo-${post.id}', child: image);
              }
              return image;
            },
          ),
        ),
        if (post.photos.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < post.photos.length; i++)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == currentPage ? 8 : 6,
                  height: i == currentPage ? 8 : 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == currentPage
                        ? AppColors.primary
                        : AppColors.outline,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
