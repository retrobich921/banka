import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../cubit/add_comment_cubit.dart';

/// Поле ввода комментария + кнопка отправки.
///
/// Сам ввод хранится в `AddCommentCubit` (родитель оборачивает виджет в
/// `BlocProvider<AddCommentCubit>`). После успеха — очищает контроллер
/// и убирает фокус.
class CommentInput extends StatefulWidget {
  const CommentInput({super.key, required this.postId});

  final String postId;

  @override
  State<CommentInput> createState() => _CommentInputState();
}

class _CommentInputState extends State<CommentInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth.isAuthenticated ? auth.user : null;

    return BlocConsumer<AddCommentCubit, AddCommentState>(
      listenWhen: (a, b) => a.status != b.status,
      listener: (context, state) {
        if (state.status == AddCommentStatus.success) {
          _controller.clear();
          _focusNode.unfocus();
          context.read<AddCommentCubit>().acknowledged();
        } else if (state.status == AddCommentStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          context.read<AddCommentCubit>().acknowledged();
        }
      },
      builder: (context, state) {
        if (user == null) {
          return Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.surface,
            child: const Text(
              'Войдите, чтобы оставить комментарий',
              style: TextStyle(color: AppColors.onSurfaceMuted),
            ),
          );
        }
        final canSubmit = state.canSubmit;
        return SafeArea(
          top: false,
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.outline)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: AddCommentCubit.maxLength,
                    enabled: !state.isSubmitting,
                    decoration: const InputDecoration(
                      hintText: 'Написать комментарий…',
                      border: InputBorder.none,
                      counterText: '',
                      isDense: true,
                    ),
                    onChanged: context.read<AddCommentCubit>().textChanged,
                  ),
                ),
                IconButton(
                  tooltip: 'Отправить',
                  onPressed: canSubmit
                      ? () => context.read<AddCommentCubit>().submit(
                          postId: widget.postId,
                          authorId: user.id,
                          authorName: user.displayName ?? user.email,
                          authorPhotoUrl: user.photoUrl,
                        )
                      : null,
                  icon: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.send,
                          color: canSubmit
                              ? AppColors.primary
                              : AppColors.onSurfaceFaint,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
