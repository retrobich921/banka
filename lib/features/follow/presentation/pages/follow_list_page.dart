import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../user/domain/entities/user_profile.dart';
import '../../../user/domain/usecases/get_users_by_ids.dart';
import '../../domain/usecases/watch_follow_ids.dart';
import '../widgets/follow_button.dart';

/// Какой список показываем.
enum FollowListMode {
  following('Подписки', 'Пока ни на кого не подписан'),
  followers('Подписчики', 'Пока нет подписчиков');

  const FollowListMode(this.title, this.emptyText);

  final String title;
  final String emptyText;
}

/// Список подписок / подписчиков пользователя (как в Instagram: тап по
/// счётчику в профиле открывает этот экран).
class FollowListPage extends StatefulWidget {
  const FollowListPage({super.key, required this.userId, required this.mode});

  final String userId;
  final FollowListMode mode;

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage> {
  StreamSubscription<Either<Failure, List<String>>>? _sub;
  List<UserProfile>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    final stream = widget.mode == FollowListMode.following
        ? sl<WatchFollowingIds>()(widget.userId)
        : sl<WatchFollowerIds>()(widget.userId);
    _sub = stream.listen(_onIds);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onIds(Either<Failure, List<String>> result) async {
    final ids = result.fold((failure) {
      if (mounted) {
        setState(() => _error = failure.message ?? 'Не удалось загрузить');
      }
      return null;
    }, (ids) => ids);
    if (ids == null) return;

    if (ids.isEmpty) {
      if (mounted) setState(() => _users = const []);
      return;
    }

    final profiles = await sl<GetUsersByIds>()(ids);
    if (!mounted) return;
    profiles.fold(
      (failure) =>
          setState(() => _error = failure.message ?? 'Не удалось загрузить'),
      (list) => setState(() {
        _error = null;
        _users = list;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.mode.title)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) return _Hint(text: _error!);
    final users = _users;
    if (users == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (users.isEmpty) return _Hint(text: widget.mode.emptyText);

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: users.length,
      itemBuilder: (context, i) {
        final user = users[i];
        return ListTile(
          onTap: () => context.pushNamed(
            AppRoutes.userProfileName,
            pathParameters: {'id': user.id},
          ),
          leading: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.surfaceVariant,
            backgroundImage:
                (user.photoUrl != null && user.photoUrl!.isNotEmpty)
                ? CachedNetworkImageProvider(user.photoUrl!)
                : null,
            child: (user.photoUrl == null || user.photoUrl!.isEmpty)
                ? const Icon(Icons.person_outline, size: 22)
                : null,
          ),
          title: Text(
            user.displayName.isEmpty ? 'Коллекционер' : user.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          subtitle: user.username.isEmpty
              ? null
              : Text(
                  '@${user.username}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceMuted,
                  ),
                ),
          trailing: FollowButton(targetUserId: user.id),
        );
      },
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
