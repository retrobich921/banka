import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/activity_service.dart';

/// Колокольчик в AppBar ленты: точка-бейдж, если по твоим постам есть
/// непросмотренные лайки/комменты. Тап → экран «Активность».
class ActivityBell extends StatefulWidget {
  const ActivityBell({super.key});

  @override
  State<ActivityBell> createState() => _ActivityBellState();
}

class _ActivityBellState extends State<ActivityBell> {
  bool _hasUnseen = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final userId = context.read<AuthBloc>().state.user?.id;
    if (userId == null) return;
    try {
      final service = sl<ActivityService>();
      final items = await service.fetchActivity(userId, postsLimit: 8);
      final unseen = await service.hasUnseen(items);
      if (mounted) setState(() => _hasUnseen = unseen);
    } catch (_) {
      // Бейдж — не критичен: молча остаёмся без точки.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Активность',
      onPressed: () async {
        setState(() => _hasUnseen = false);
        await context.pushNamed(AppRoutes.activityName);
      },
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_none),
          if (_hasUnseen)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
