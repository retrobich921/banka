import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/achievement.dart';
import '../bloc/profile_bloc.dart';
import '../widgets/achievement_icon_view.dart';

/// Экран «Достижения» текущего пользователя.
///
/// Полученные ачивки можно закрепить (до [_maxPinned] штук) — именно они
/// показываются в шапке профиля. Невыполненные видны только здесь и без
/// порогов: у ближайшей цели — полоса прогресса, остальные закрыты.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  static const int _maxPinned = 3;

  @override
  void initState() {
    super.initState();
    // Экран открывается пушем маршрута, и go_router поднимает для него
    // собственный ProfileBloc — тот, что живёт во вкладке профиля, сюда не
    // достаёт. Без этой подписки экран висел бы на бесконечном спиннере.
    final bloc = context.read<ProfileBloc>();
    if (bloc.state.profile == null) {
      final user = context.read<AuthBloc>().state.user;
      if (user != null) bloc.add(ProfileSubscribeRequested(user));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Достижения')),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        builder: (context, state) {
          final profile = state.profile;
          if (profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final cans = profile.stats.cansCount;
          final pinned = profile.pinnedAchievements;
          final next = nextAchievement(cans);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Text(
                'Отметьте до $_maxPinned ачивок — они будут видны в вашем '
                'профиле.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceFaint,
                ),
              ),
              const SizedBox(height: 12),
              for (final a in kCollectionAchievements)
                _AchievementTile(
                  achievement: a,
                  earned: a.earnedBy(cans),
                  pinned: pinned.contains(a.id),
                  isNext: next?.id == a.id,
                  progress: next?.id == a.id
                      ? nextAchievementProgress(cans)
                      : null,
                  onTogglePin: a.earnedBy(cans)
                      ? () => _togglePin(context, pinned, a.id)
                      : null,
                ),
            ],
          );
        },
      ),
    );
  }

  void _togglePin(BuildContext context, List<String> pinned, String id) {
    final next = [...pinned];
    if (next.contains(id)) {
      next.remove(id);
    } else {
      if (next.length >= _maxPinned) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('В профиле помещается не больше трёх ачивок'),
            ),
          );
        return;
      }
      next.add(id);
    }
    context.read<ProfileBloc>().add(ProfilePinnedAchievementsChanged(next));
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.achievement,
    required this.earned,
    required this.pinned,
    required this.isNext,
    required this.progress,
    required this.onTogglePin,
  });

  final Achievement achievement;
  final bool earned;
  final bool pinned;
  final bool isNext;
  final double? progress;
  final VoidCallback? onTogglePin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pinned ? AppColors.primary : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          AchievementIconView(icon: achievement.icon, earned: earned, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: earned
                        ? AppColors.onSurface
                        : AppColors.onSurfaceMuted,
                  ),
                ),
                if (isNext && progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceVariant,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ] else if (!earned)
                  Text(
                    'Ещё не открыто',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceFaint,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (earned)
            IconButton(
              tooltip: pinned ? 'Убрать из профиля' : 'Показывать в профиле',
              onPressed: onTogglePin,
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                color: pinned ? AppColors.primary : AppColors.onSurfaceMuted,
                size: 20,
              ),
            )
          else
            const Icon(
              Icons.lock_outline,
              size: 18,
              color: AppColors.onSurfaceFaint,
            ),
        ],
      ),
    );
  }
}
