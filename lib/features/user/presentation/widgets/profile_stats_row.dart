import 'dart:async';

import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../follow/domain/usecases/watch_follow_ids.dart';
import '../../../group/domain/entities/group.dart';
import '../../../group/domain/usecases/watch_my_groups.dart';

/// Счётчики профиля: банки, подписки, подписчики, группы.
///
/// Подписки/подписчики/группы считаем «вживую» из Firestore, а не из
/// денорм-полей `users/{uid}.stats`: их некому поддерживать (Cloud
/// Functions на Spark-плане не выполняются), поэтому `stats.groupsCount`
/// всегда показывал ноль/устаревшее значение. Подписки и группы —
/// маленькие подколлекции/запрос по `membersUids`, читать их дёшево.
///
/// Тап по счётчику открывает соответствующий список (как в Instagram).
class ProfileStatsRow extends StatefulWidget {
  const ProfileStatsRow({
    super.key,
    required this.userId,
    required this.cansCount,
    this.isSelf = false,
  });

  final String userId;
  final int cansCount;
  final bool isSelf;

  @override
  State<ProfileStatsRow> createState() => _ProfileStatsRowState();
}

class _ProfileStatsRowState extends State<ProfileStatsRow> {
  StreamSubscription<Either<Failure, List<String>>>? _followingSub;
  StreamSubscription<Either<Failure, List<String>>>? _followersSub;
  StreamSubscription<Either<Failure, List<Group>>>? _groupsSub;

  int? _following;
  int? _followers;
  int? _groups;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant ProfileStatsRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _cancel();
      _following = _followers = _groups = null;
      _subscribe();
    }
  }

  void _subscribe() {
    _followingSub = sl<WatchFollowingIds>()(
      widget.userId,
    ).listen((r) => _apply(r, (n) => _following = n));
    _followersSub = sl<WatchFollowerIds>()(
      widget.userId,
    ).listen((r) => _apply(r, (n) => _followers = n));
    _groupsSub = sl<WatchMyGroups>()(
      widget.userId,
    ).listen((r) => _apply(r, (n) => _groups = n));
  }

  void _apply<T>(Either<Failure, List<T>> result, void Function(int) assign) {
    result.fold((_) {}, (list) {
      if (!mounted) return;
      setState(() => assign(list.length));
    });
  }

  void _cancel() {
    _followingSub?.cancel();
    _followersSub?.cancel();
    _groupsSub?.cancel();
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatCell(label: 'Банок', value: '${widget.cansCount}'),
        _StatCell(
          label: 'Подписки',
          value: _format(_following),
          onTap: () => context.pushNamed(
            AppRoutes.userFollowingName,
            pathParameters: {'id': widget.userId},
          ),
        ),
        _StatCell(
          label: 'Подписчики',
          value: _format(_followers),
          onTap: () => context.pushNamed(
            AppRoutes.userFollowersName,
            pathParameters: {'id': widget.userId},
          ),
        ),
        _StatCell(
          label: 'Группы',
          value: _format(_groups),
          onTap: () => context.pushNamed(
            AppRoutes.userGroupsName,
            pathParameters: {'id': widget.userId},
            queryParameters: widget.isSelf ? const {'self': '1'} : const {},
          ),
        ),
      ],
    );
  }

  static String _format(int? value) => value?.toString() ?? '—';
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceFaint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
