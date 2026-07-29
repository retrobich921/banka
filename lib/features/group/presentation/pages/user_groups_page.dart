import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/group.dart';
import '../../domain/usecases/watch_my_groups.dart';

/// Группы конкретного пользователя — открывается тапом по счётчику
/// «Группы» в профиле (своём или чужом).
class UserGroupsPage extends StatefulWidget {
  const UserGroupsPage({super.key, required this.userId, this.isSelf = false});

  final String userId;
  final bool isSelf;

  @override
  State<UserGroupsPage> createState() => _UserGroupsPageState();
}

class _UserGroupsPageState extends State<UserGroupsPage> {
  late final Stream<Either<Failure, List<Group>>> _stream = sl<WatchMyGroups>()(
    widget.userId,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Группы')),
      body: StreamBuilder<Either<Failure, List<Group>>>(
        stream: _stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return snapshot.data!.fold(
            (failure) =>
                _Hint(text: failure.message ?? 'Не удалось загрузить группы'),
            (groups) {
              if (groups.isEmpty) {
                return _Hint(
                  text: widget.isSelf
                      ? 'Вы пока не состоите ни в одной группе.'
                      : 'Пользователь пока не состоит в группах.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: groups.length,
                itemBuilder: (context, i) => _GroupTile(group: groups[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});

  final Group group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cover = group.coverUrl;
    return ListTile(
      onTap: () => context.pushNamed(
        AppRoutes.groupDetailName,
        pathParameters: {'id': group.id},
      ),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: (cover == null || cover.isEmpty)
            ? Container(
                width: 44,
                height: 44,
                color: AppColors.surfaceVariant,
                child: const Icon(
                  Icons.group_outlined,
                  color: AppColors.onSurfaceMuted,
                ),
              )
            : CachedNetworkImage(
                imageUrl: cover,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
      ),
      title: Text(
        group.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleSmall,
      ),
      subtitle: Text(
        '${group.membersCount} участников · ${group.postsCount} банок',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(
          color: AppColors.onSurfaceMuted,
        ),
      ),
      trailing: group.isPublic
          ? null
          : const Icon(
              Icons.lock_outline,
              size: 16,
              color: AppColors.onSurfaceFaint,
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
