import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/usecases/delete_comment.dart';
import '../bloc/comments_bloc.dart';
import '../cubit/add_comment_cubit.dart';
import 'comment_input.dart';
import 'comment_tile.dart';

/// Секция комментариев на детальном экране поста.
///
/// Поднимает `CommentsBloc` + `AddCommentCubit` через DI, рендерит ленту
/// (loading / error / empty / list) и форму ввода. Удаление вызывает
/// `DeleteComment` напрямую (одноразовый вызов, нет смысла заводить cubit).
class CommentsSection extends StatelessWidget {
  const CommentsSection({super.key, required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<CommentsBloc>(
          create: (_) =>
              sl<CommentsBloc>()..add(CommentsSubscribeRequested(postId)),
        ),
        BlocProvider<AddCommentCubit>(create: (_) => sl<AddCommentCubit>()),
      ],
      child: _CommentsSectionView(postId: postId),
    );
  }
}

class _CommentsSectionView extends StatelessWidget {
  const _CommentsSectionView({required this.postId});

  final String postId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Text(
            'Комментарии',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        BlocBuilder<CommentsBloc, CommentsState>(
          builder: (context, state) {
            if (state.isLoading || state.status == CommentsStatus.initial) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (state.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: Text(
                  state.errorMessage ?? 'Ошибка загрузки',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                  ),
                ),
              );
            }
            if (state.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                child: Text(
                  'Будь первым, кто прокомментирует.',
                  style: TextStyle(color: AppColors.onSurfaceMuted),
                ),
              );
            }
            final auth = context.watch<AuthBloc>().state;
            final currentUid = auth.isAuthenticated ? auth.user?.id : null;
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: state.comments.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.outline, height: 1),
              itemBuilder: (_, i) {
                final comment = state.comments[i];
                final mine =
                    currentUid != null && currentUid == comment.authorId;
                return CommentTile(
                  comment: comment,
                  canDelete: mine,
                  onDelete: () => _confirmDelete(context, comment.id),
                );
              },
            );
          },
        ),
        const SizedBox(height: 8),
        CommentInput(postId: postId),
      ],
    );
  }

  Future<void> _confirmDelete(BuildContext context, String commentId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Удалить комментарий?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final result = await sl<DeleteComment>()(
      DeleteCommentParams(postId: postId, commentId: commentId),
    );
    result.fold(
      (failure) => messenger.showSnackBar(
        SnackBar(content: Text(failure.message ?? 'Не удалось удалить')),
      ),
      (_) {},
    );
  }
}
