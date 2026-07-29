import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../cubit/like_button_cubit.dart';

/// Кнопка лайка с оптимистичным UI.
///
/// Создаёт собственный `LikeButtonCubit` через DI, подписывается на
/// `watchHasLiked(postId, currentUid)` и показывает суммарный счётчик =
/// `baseLikesCount + cubit.optimisticDelta`. На каждый пост — свой инстанс
/// (cubit живёт пока виджет в дереве).
///
/// `ValueKey(postId)` на провайдере обязателен: списки переиспользуют
/// элементы, и без ключа cubit остался бы подписанным на старый пост —
/// лайк уходил бы «не туда», а счётчик не обновлялся.
class LikeButton extends StatelessWidget {
  const LikeButton({
    super.key,
    required this.postId,
    required this.likesCount,
    this.iconSize = 20,
    this.compact = false,
  });

  final String postId;
  final int likesCount;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final user = auth.isAuthenticated ? auth.user : null;

    if (user == null) {
      return _LikeButtonView(
        compact: compact,
        iconSize: iconSize,
        hasLiked: false,
        count: likesCount,
        onTap: null,
      );
    }

    return BlocProvider<LikeButtonCubit>(
      key: ValueKey(postId),
      create: (_) => sl<LikeButtonCubit>()
        ..subscribe(
          postId: postId,
          userId: user.id,
          userName: user.displayName ?? user.email,
          userPhotoUrl: user.photoUrl,
          likesCount: likesCount,
        ),
      child: _LikeButtonInner(
        likesCount: likesCount,
        compact: compact,
        iconSize: iconSize,
      ),
    );
  }
}

class _LikeButtonInner extends StatefulWidget {
  const _LikeButtonInner({
    required this.likesCount,
    required this.compact,
    required this.iconSize,
  });

  final int likesCount;
  final bool compact;
  final double iconSize;

  @override
  State<_LikeButtonInner> createState() => _LikeButtonInnerState();
}

class _LikeButtonInnerState extends State<_LikeButtonInner> {
  @override
  void didUpdateWidget(covariant _LikeButtonInner oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Родитель отдал свежий серверный счётчик — снимаем локальную поправку.
    if (oldWidget.likesCount != widget.likesCount) {
      context.read<LikeButtonCubit>().syncLikesCount(widget.likesCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LikeButtonCubit, LikeButtonState>(
      listenWhen: (a, b) =>
          b.status == LikeButtonStatus.error &&
          b.errorMessage != null &&
          a.errorMessage != b.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        return _LikeButtonView(
          compact: widget.compact,
          iconSize: widget.iconSize,
          hasLiked: state.displayedHasLiked,
          count: state.displayedCount,
          onTap: state.isMutating
              ? null
              : () => context.read<LikeButtonCubit>().toggle(),
        );
      },
    );
  }
}

class _LikeButtonView extends StatelessWidget {
  const _LikeButtonView({
    required this.compact,
    required this.iconSize,
    required this.hasLiked,
    required this.count,
    required this.onTap,
  });

  final bool compact;
  final double iconSize;
  final bool hasLiked;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = hasLiked ? AppColors.primary : AppColors.onSurfaceMuted;
    final icon = Icon(
      hasLiked ? Icons.favorite : Icons.favorite_border,
      size: iconSize,
      color: color,
    );
    final label = Text(
      '$count',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            SizedBox(width: compact ? 4 : 6),
            label,
          ],
        ),
      ),
    );
  }
}
