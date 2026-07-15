import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../comment/presentation/widgets/comments_section.dart';
import '../../../like/presentation/widgets/like_button.dart';
import '../../domain/entities/drink_rating.dart';
import '../../domain/entities/post.dart';
import '../bloc/post_detail_bloc.dart';
import '../widgets/rating_widgets.dart';

/// Детальный экран поста-«банки».
///
/// Подписывается на стрим конкретного поста через `PostDetailBloc`,
/// чтобы реагировать на live-обновления лайков/комментов.
class PostDetailPage extends StatelessWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PostDetailBloc>(
      create: (_) =>
          sl<PostDetailBloc>()..add(PostDetailSubscribeRequested(postId)),
      child: _PostDetailView(postId: postId),
    );
  }
}

class _PostDetailView extends StatefulWidget {
  const _PostDetailView({required this.postId});

  final String postId;

  @override
  State<_PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<_PostDetailView> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить банку?'),
        content: const Text(
          'Пост будет удалён безвозвратно вместе с лайками и комментариями.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<PostDetailBloc>().add(const PostDetailDeleteRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PostDetailBloc, PostDetailState>(
      listenWhen: (prev, curr) => prev.status != curr.status,
      listener: (context, state) {
        if (state.status == PostDetailStatus.deleted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Пост удалён')));
          context.canPop()
              ? context.pop()
              : context.goNamed(AppRoutes.homeName);
          return;
        }
        if (state.status == PostDetailStatus.error &&
            state.errorMessage != null &&
            state.post != null) {
          // Ошибка при удалении: пост на экране остаётся, показываем снекбар.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final post = state.post;
        final currentUserId = context.read<AuthBloc>().state.user?.id;
        final isAuthor =
            post != null &&
            currentUserId != null &&
            post.authorId == currentUserId;
        final isDeleting = state.status == PostDetailStatus.deleting;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Банка'),
            actions: [
              if (isAuthor)
                IconButton(
                  tooltip: post.archived
                      ? 'Вернуть из архива'
                      : 'В архив (можно вернуть)',
                  icon: Icon(
                    post.archived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () => context.read<PostDetailBloc>().add(
                          PostDetailArchiveToggleRequested(
                            archived: !post.archived,
                          ),
                        ),
                ),
              if (isAuthor)
                IconButton(
                  tooltip: 'Удалить пост',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: isDeleting ? null : () => _confirmDelete(context),
                ),
            ],
          ),
          body: _buildBody(state, post, isDeleting),
        );
      },
    );
  }

  Widget _buildBody(PostDetailState state, Post? post, bool isDeleting) {
    if (state.status == PostDetailStatus.error &&
        state.errorMessage != null &&
        post == null) {
      return _CenteredText(text: state.errorMessage!);
    }
    if (state.status == PostDetailStatus.notFound) {
      return const _CenteredText(text: 'Пост не найден или удалён');
    }
    if (post == null || isDeleting) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.archived)
            Container(
              width: double.infinity,
              color: AppColors.surfaceVariant,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.archive_outlined,
                    size: 18,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Пост в архиве — скрыт из лент',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          if (post.photos.isNotEmpty)
            _Carousel(
              post: post,
              pageController: _pageController,
              currentPage: _currentPage,
              onPageChanged: (i) => setState(() => _currentPage = i),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: _PostBody(post: post),
          ),
          const Divider(color: AppColors.outline, height: 1),
          CommentsSection(postId: post.id),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({
    required this.post,
    required this.pageController,
    required this.currentPage,
    required this.onPageChanged,
  });

  final Post post;
  final PageController pageController;
  final int currentPage;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: PageView.builder(
            controller: pageController,
            itemCount: post.photos.length,
            onPageChanged: onPageChanged,
            itemBuilder: (context, i) {
              final photo = post.photos[i];
              final image = CachedNetworkImage(
                imageUrl: photo.url,
                fit: BoxFit.cover,
                placeholder: (_, _) =>
                    const ColoredBox(color: AppColors.surfaceVariant),
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  color: AppColors.onSurfaceFaint,
                ),
              );
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
                  width: i == currentPage ? 10 : 7,
                  height: i == currentPage ? 10 : 7,
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

class _PostBody extends StatelessWidget {
  const _PostBody({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foundDateText = post.foundDate != null
        ? DateFormat('d MMMM yyyy', 'ru_RU').format(post.foundDate!)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(post.drinkName, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.pushNamed(
                AppRoutes.userProfileName,
                pathParameters: {'id': post.authorId},
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppColors.onSurfaceMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    post.authorName.isNotEmpty ? post.authorName : 'Аноним',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (foundDateText != null) ...[
              const SizedBox(width: 12),
              const Icon(
                Icons.event_outlined,
                size: 16,
                color: AppColors.onSurfaceMuted,
              ),
              const SizedBox(width: 4),
              Text(
                foundDateText,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ],
          ],
        ),
        if (post.rating != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Text('Оценка', style: theme.textTheme.titleSmall),
              const SizedBox(width: 8),
              RatingScoreBadge(score: post.rating!.score),
            ],
          ),
          const SizedBox(height: 8),
          _RatingBreakdown(rating: post.rating!),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Chip(
              icon: Icons.local_drink_outlined,
              label: post.drinkType.label,
            ),
            if (post.brandName != null && post.brandName!.isNotEmpty)
              _Chip(icon: Icons.local_bar_outlined, label: post.brandName!),
            if (post.groupName != null)
              _Chip(icon: Icons.group_outlined, label: post.groupName!),
          ],
        ),
        if (post.description.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Отзыв',
            style: theme.textTheme.titleSmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(post.description, style: theme.textTheme.bodyLarge),
        ],
        if (post.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final t in post.tags)
                Text(
                  '#$t',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        const Divider(color: AppColors.outline, height: 1),
        const SizedBox(height: 8),
        Row(
          children: [
            LikeButton(postId: post.id, likesCount: post.likesCount),
            TextButton(
              onPressed: () => context.pushNamed(
                AppRoutes.whoLikedName,
                pathParameters: {'id': post.id},
              ),
              child: const Text('Кто лайкнул'),
            ),
            const Spacer(),
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
      ],
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({required this.rating});

  final DrinkRating rating;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int)>[
      ('Вкус', rating.taste),
      ('Баланс', rating.balance),
      ('Текстура', rating.texture),
      ('Послевкусие', rating.aftertaste),
      ('Дизайн', rating.design),
      ('Вайб', rating.vibe),
    ];
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final (label, value) in items)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$label · $value',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
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

class _CenteredText extends StatelessWidget {
  const _CenteredText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
