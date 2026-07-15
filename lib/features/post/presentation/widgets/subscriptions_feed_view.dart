import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../bloc/subscriptions_feed_bloc.dart';
import 'post_card.dart';

/// Лента «Подписки»: посты людей, на которых подписан пользователь,
/// и групп, где он состоит. Pull-to-refresh перезагружает ленту.
class SubscriptionsFeedView extends StatelessWidget {
  const SubscriptionsFeedView({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionsFeedBloc, SubscriptionsFeedState>(
      builder: (context, state) {
        if (state.status == SubscriptionsFeedStatus.initial ||
            (state.status == SubscriptionsFeedStatus.loading &&
                state.posts.isEmpty)) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.status == SubscriptionsFeedStatus.error) {
          return _CenteredText(
            text: state.errorMessage ?? 'Не удалось загрузить ленту',
          );
        }

        Future<void> refresh() async {
          final bloc = context.read<SubscriptionsFeedBloc>();
          bloc.add(SubscriptionsFeedRequested(userId));
          await bloc.stream.firstWhere(
            (s) => s.status != SubscriptionsFeedStatus.loading,
          );
        }

        if (state.posts.isEmpty) {
          // RefreshIndicator требует скроллируемого ребёнка даже для пустоты.
          return RefreshIndicator(
            onRefresh: refresh,
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: _CenteredText(
                    text: state.hasSubscriptions
                        ? 'В твоих подписках пока нет постов.'
                        : 'Подпишись на коллекционеров и вступай в группы —\n'
                              'их посты появятся здесь.',
                  ),
                ),
              ),
            ),
          );
        }

        final posts = state.posts;
        return RefreshIndicator(
          onRefresh: refresh,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, i) => PostCard(
              post: posts[i],
              onTap: () => context.pushNamed(
                AppRoutes.postDetailName,
                pathParameters: {'id': posts[i].id},
              ),
              onAuthorTap: () => context.pushNamed(
                AppRoutes.userProfileName,
                pathParameters: {'id': posts[i].authorId},
              ),
            ),
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
