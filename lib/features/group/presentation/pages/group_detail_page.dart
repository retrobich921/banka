import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../core/error/failures.dart';
import '../../../post/presentation/bloc/posts_feed_bloc.dart';
import '../../../post/presentation/widgets/post_card.dart';
import '../../../user/domain/entities/user_profile.dart';
import '../../../user/domain/usecases/watch_user.dart';
import '../../domain/entities/group.dart';
import '../bloc/group_detail_bloc.dart';
import 'join_requests_page.dart';

/// Экран конкретной группы.
///
/// `GroupDetailBloc` создаётся локально (по экрану на экземпляр), потому
/// что подписки на стрим конкретной группы — не разделяемое состояние.
class GroupDetailPage extends StatelessWidget {
  const GroupDetailPage({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<GroupDetailBloc>(create: (_) => sl<GroupDetailBloc>()),
        BlocProvider<PostsFeedBloc>(
          create: (_) => sl<PostsFeedBloc>()
            ..add(PostsFeedSubscribeRequested(PostsFeedScope.group(groupId))),
        ),
      ],
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
          currentUserDisplayName: user.displayName,
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
        final userId = context.read<AuthBloc>().state.user?.id;
        final canPost =
            group != null && userId != null && group.canPost(userId);

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: state.isMember && group != null && canPost
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
              if (state.isOwner && group != null && !group.isPublic)
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  tooltip: 'Запросы на вступление',
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => JoinRequestsPage(groupId: group.id),
                    ),
                  ),
                ),
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
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить группу?'),
        content: const Text(
          'Действие нельзя отменить. Участники и запросы на вступление будут '
          'удалены автоматически. Посты в группе останутся, но будут отвязаны.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
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
          // Название группы уже в AppBar — здесь не дублируем.
          if (group.description.isNotEmpty) ...[
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
          if (group.postingPolicy == GroupPostingPolicy.admins) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  size: 16,
                  color: AppColors.onSurfaceMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Публикуют только владелец и админы',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          _MembershipButton(state: state),
          const SizedBox(height: 32),
          Text('Участники', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ...state.members.map(
            (m) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                switch (m.role) {
                  GroupRole.owner => Icons.shield_outlined,
                  GroupRole.admin => Icons.verified_user_outlined,
                  GroupRole.member => Icons.person_outline,
                },
                color: m.role == GroupRole.member
                    ? AppColors.onSurfaceMuted
                    : AppColors.primary,
              ),
              title: _MemberName(member: m),
              subtitle: Text(_roleLabel(m.role)),
              // Владелец управляет ролями остальных участников.
              trailing: state.isOwner && m.role != GroupRole.owner
                  ? PopupMenuButton<GroupRole>(
                      tooltip: 'Роль участника',
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.onSurfaceMuted,
                      ),
                      onSelected: state.isMutating
                          ? null
                          : (role) => context.read<GroupDetailBloc>().add(
                              GroupDetailSetRoleRequested(
                                userId: m.userId,
                                role: role,
                              ),
                            ),
                      itemBuilder: (_) => [
                        if (m.role != GroupRole.admin)
                          const PopupMenuItem(
                            value: GroupRole.admin,
                            child: Text('Сделать админом'),
                          )
                        else
                          const PopupMenuItem(
                            value: GroupRole.member,
                            child: Text('Снять админа'),
                          ),
                      ],
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 32),
          Text('Банки группы', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _GroupPostsSection(),
          const SizedBox(height: 80),
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

/// Имя участника. В легаси member-документах `displayName` пустой (или туда
/// попадал uid) — тогда резолвим имя из профиля `users/{uid}`.
class _MemberName extends StatelessWidget {
  const _MemberName({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    final denormalized = member.displayName.trim();
    // Не показываем uid, даже если он записан в displayName.
    final hasRealName =
        denormalized.isNotEmpty && denormalized != member.userId;
    if (hasRealName) return Text(denormalized);

    return StreamBuilder<Either<Failure, UserProfile?>>(
      stream: sl<WatchUser>().call(member.userId),
      builder: (context, snapshot) {
        final profile = snapshot.data?.fold<UserProfile?>(
          (_) => null,
          (p) => p,
        );
        final name = profile?.displayName.trim() ?? '';
        return Text(name.isNotEmpty ? name : 'Коллекционер');
      },
    );
  }
}

class _GroupPostsSection extends StatelessWidget {
  const _GroupPostsSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PostsFeedBloc, PostsFeedState>(
      builder: (context, state) {
        if (state.status == PostsFeedStatus.error &&
            state.errorMessage != null) {
          return Text(
            state.errorMessage!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
          );
        }
        if (state.isLoading && state.posts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.posts.isEmpty) {
          return Text(
            'В этой группе ещё нет постов.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
          );
        }
        return Column(
          children: [
            for (final post in state.posts) ...[
              PostCard(
                post: post,
                onTap: () => context.pushNamed(
                  AppRoutes.postDetailName,
                  pathParameters: {'id': post.id},
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _MembershipButton extends StatelessWidget {
  const _MembershipButton({required this.state});

  final GroupDetailState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<GroupDetailBloc>();
    final group = state.group;

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

    final isPrivate = group != null && !group.isPublic;
    final hasPendingRequest = state.hasPendingRequest;

    // Если есть ожидающий запрос, показываем серую кнопку
    if (hasPendingRequest) {
      return FilledButton.icon(
        onPressed: null, // Кнопка неактивна
        icon: const Icon(Icons.schedule),
        label: const Text('Запрос отправлен'),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          foregroundColor: AppColors.onSurfaceMuted,
        ),
      );
    }

    return FilledButton.icon(
      onPressed: state.isMutating
          ? null
          : () => bloc.add(const GroupDetailJoinRequested()),
      icon: Icon(isPrivate ? Icons.lock_outline : Icons.add),
      label: Text(isPrivate ? 'Запросить вступление' : 'Вступить'),
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
