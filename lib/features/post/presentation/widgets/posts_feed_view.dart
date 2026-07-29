import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/posts_feed_bloc.dart';
import '../pages/post_detail_page.dart';
import 'collapsible_item.dart';
import 'post_card.dart';

/// Список постов из `PostsFeedBloc` с пустым/ошибочным/загрузочным
/// состояниями и переходом на детальный экран по тапу карточки.
class PostsFeedView extends StatefulWidget {
  const PostsFeedView({super.key, this.emptyText = 'Здесь пока пусто'});

  final String emptyText;

  @override
  State<PostsFeedView> createState() => _PostsFeedViewState();
}

class _PostsFeedViewState extends State<PostsFeedView> {
  /// Посты, которые сейчас «схлопываются» после архивации.
  final Set<String> _collapsing = <String>{};

  Future<void> _openPost(BuildContext context, String postId) async {
    final result = await context.pushNamed<Object?>(
      AppRoutes.postDetailName,
      pathParameters: {'id': postId},
    );
    if (result == kPostArchivedResult && mounted) {
      setState(() => _collapsing.add(postId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostsFeedBloc, PostsFeedState>(
      builder: (context, state) {
        if (state.status == PostsFeedStatus.error &&
            state.errorMessage != null) {
          return _CenteredText(text: state.errorMessage!);
        }
        if (state.isLoading && state.posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.posts.isEmpty) {
          return _CenteredText(text: widget.emptyText);
        }
        final posts = state.posts;
        // Нижний лоадер-«хвост» во время догрузки следующей страницы.
        final itemCount = posts.length + (state.isLoadingMore ? 1 : 0);
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final metrics = notification.metrics;
            // Подгружаем заранее (за 400px до конца), чтобы скролл был плавным.
            if (metrics.pixels >= metrics.maxScrollExtent - 400 &&
                !state.isLoadingMore &&
                !state.hasReachedEnd) {
              context.read<PostsFeedBloc>().add(
                const PostsFeedLoadMoreRequested(),
              );
            }
            return false;
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
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
                  context.read<PostsFeedBloc>().add(
                    PostsFeedPostHidden(post.id),
                  );
                  _collapsing.remove(post.id);
                },
                child: PostCard(
                  // Ключ обязателен: без него элементы списка
                  // переиспользуются между постами и состояние карточки
                  // (карусель, кнопка лайка) «прилипает» к чужому посту.
                  key: ValueKey(post.id),
                  post: post,
                  onTap: () => _openPost(context, post.id),
                  onAuthorTap: () => context.pushNamed(
                    AppRoutes.userProfileName,
                    pathParameters: {'id': post.authorId},
                  ),
                ),
              );
            },
          ),
        );
      },
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
