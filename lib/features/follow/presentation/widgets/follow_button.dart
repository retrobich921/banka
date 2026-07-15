import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../cubit/follow_button_cubit.dart';

/// Кнопка «Подписаться / Вы подписаны» для чужого профиля.
///
/// Сама скрывается, если смотрим собственный профиль или не залогинены.
class FollowButton extends StatelessWidget {
  const FollowButton({super.key, required this.targetUserId});

  final String targetUserId;

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.watch<AuthBloc>().state.user?.id;
    if (currentUserId == null || currentUserId == targetUserId) {
      return const SizedBox.shrink();
    }
    return BlocProvider<FollowButtonCubit>(
      create: (_) =>
          sl<FollowButtonCubit>()
            ..subscribe(followerId: currentUserId, targetUserId: targetUserId),
      child: const _FollowButtonView(),
    );
  }
}

class _FollowButtonView extends StatelessWidget {
  const _FollowButtonView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowButtonCubit, FollowButtonState>(
      builder: (context, state) {
        if (!state.known) return const SizedBox(height: 40);
        final cubit = context.read<FollowButtonCubit>();
        return state.isFollowing
            ? OutlinedButton.icon(
                onPressed: state.busy ? null : cubit.toggle,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Вы подписаны'),
              )
            : FilledButton.icon(
                onPressed: state.busy ? null : cubit.toggle,
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: const Text('Подписаться'),
              );
      },
    );
  }
}
