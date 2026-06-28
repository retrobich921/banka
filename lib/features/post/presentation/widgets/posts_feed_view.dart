import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/posts_feed_bloc.dart';
import 'post_card.dart';

/// Список постов из `PostsFeedBloc` с пустым/ошибочным/загрузочным
/// состояниями и переходом на детальный экран по тапу карточки.
class PostsFeedView extends StatelessWidget {
  const PostsFeedView({super.key, this.emptyText = 'Здесь пока пусто'});

  final String emptyText;

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
          return _CenteredText(text: emptyText);
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
              return PostCard(
                post: posts[i],
                onTap: () => context.pushNamed(
                  AppRoutes.postDetailName,
                  pathParameters: {'id': posts[i].id},
                ),
                onAuthorTap: () => context.pushNamed(
                  AppRoutes.userProfileName,
                  pathParameters: {'id': posts[i].authorId},
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
