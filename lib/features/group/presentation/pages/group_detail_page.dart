import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/group.dart';
import '../bloc/group_detail_bloc.dart';

/// Экран конкретной группы.
///
/// `GroupDetailBloc` создаётся локально (по экрану на экземпляр), потому
/// что подписки на стрим конкретной группы — не разделяемое состояние.
class GroupDetailPage extends StatelessWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<GroupDetailBloc>(
      create: (_) => sl<GroupDetailBloc>(),
      child: _GroupDetailView(groupId: groupId),
    );
  }
}

class _GroupDetailView extends StatefulWidget {
  const _GroupDetailView({required this.groupId});

  final String groupId;

  @override
  State<_GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<_GroupDetailView> {
  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      context.read<GroupDetailBloc>().add(
        GroupDetailSubscribeRequested(
          groupId: widget.groupId,
          currentUserId: user.id,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupDetailBloc, GroupDetailState>(
      listenWhen: (prev, curr) =>
          (prev.errorMessage != curr.errorMessage &&
              curr.errorMessage != null) ||
          (prev.status != curr.status &&
              curr.status == GroupDetailStatus.deleted),
      listener: (context, state) {
        if (state.status == GroupDetailStatus.deleted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Группа удалена')));
          context.go('/groups');
          return;
        }
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
        }
      },
      builder: (context, state) {
        final group = state.group;
        final isLoading =
            state.status == GroupDetailStatus.initial ||
            (state.status == GroupDetailStatus.loading && group == null);

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: state.isMember && group != null
              ? FloatingActionButton.extended(
                  onPressed: () => context.pushNamed(
                    AppRoutes.postCreateName,
                    extra: <String, String?>{
                      'groupId': group.id,
                      'groupName': group.name,
                    },
                  ),
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: const Text('Запостить банку'),
                )
              : null,
          appBar: AppBar(
            title: Text(group?.name ?? 'Группа'),
            actions: [
              if (state.isOwner)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Удалить группу',
                  onPressed: state.isMutating
                      ? null
                      : () => _confirmDelete(context),
                ),
            ],
          ),
          body: isLoading
              ? const Center(child: CircularProgressIndicator())
              : state.status == GroupDetailStatus.notFound
              ? const _NotFoundView()
              : _GroupBody(state: state),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bloc = context.read<GroupDetailBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: const Text(
          'Действие нельзя отменить. Посты в группе останутся, но будут '
          'отвязаны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      bloc.add(const GroupDetailDeleteRequested());
    }
  }
}

class _GroupBody extends StatelessWidget {
  const _GroupBody({required this.state});

  final GroupDetailState state;

  @override
  Widget build(BuildContext context) {
    final group = state.group!;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (group.coverUrl != null && group.coverUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                group.coverUrl!,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          Text(group.name, style: theme.textTheme.titleLarge),
          if (group.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              group.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceMuted,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              _Stat(label: 'участников', value: group.membersCount),
              const SizedBox(width: 24),
              _Stat(label: 'постов', value: group.postsCount),
              const SizedBox(width: 24),
              _Privacy(isPublic: group.isPublic),
            ],
          ),
          const SizedBox(height: 24),
          _MembershipButton(state: state),
          const SizedBox(height: 32),
          Text('Участники', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...state.members.map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.person_outline,
                color: AppColors.onSurfaceMuted,
              ),
              title: Text(m.userId),
              subtitle: Text(_roleLabel(m.role)),
            ),
          ),
        ],
      ),
    );
  }

  static String _roleLabel(GroupRole role) => switch (role) {
    GroupRole.owner => 'владелец',
    GroupRole.admin => 'админ',
    GroupRole.member => 'участник',
  };
}

class _MembershipButton extends StatelessWidget {
  const _MembershipButton({required this.state});

  final GroupDetailState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GroupDetailBloc>();
    if (state.isOwner) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Ты владелец этой группы'),
          ],
        ),
      );
    }
    if (state.isMember) {
      return OutlinedButton.icon(
        onPressed: state.isMutating
            ? null
            : () => bloc.add(const GroupDetailLeaveRequested()),
        icon: const Icon(Icons.logout),
        label: const Text('Выйти из группы'),
      );
    }
    return FilledButton.icon(
      onPressed: state.isMutating
          ? null
          : () => bloc.add(const GroupDetailJoinRequested()),
      icon: const Icon(Icons.add),
      label: const Text('Вступить'),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy({required this.isPublic});

  final bool isPublic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          isPublic ? Icons.public : Icons.lock_outline,
          size: 16,
          color: AppColors.onSurfaceMuted,
        ),
        const SizedBox(width: 4),
        Text(
          isPublic ? 'публичная' : 'закрытая',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
      ],
    );
  }
}

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: AppColors.onSurfaceFaint,
            ),
            const SizedBox(height: 12),
            Text(
              'Группа не найдена',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
