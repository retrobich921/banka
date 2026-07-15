import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/achievement.dart';

/// Горизонтальный ряд бейджей-ачивок в профиле.
///
/// Полученные — цветные; неполученные — приглушённые, с прогрессом
/// «237/300» под названием.
class AchievementsRow extends StatelessWidget {
  const AchievementsRow({super.key, required this.cansCount});

  final int cansCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: kCollectionAchievements.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => _Badge(
          achievement: kCollectionAchievements[i],
          cansCount: cansCount,
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.achievement, required this.cansCount});

  final Achievement achievement;
  final int cansCount;

  @override
  Widget build(BuildContext context) {
    final earned = achievement.earnedBy(cansCount);
    final theme = Theme.of(context);
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      decoration: BoxDecoration(
        color: earned ? AppColors.surface : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: earned ? AppColors.primary : AppColors.outline,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: earned ? 1 : 0.35,
            child: Text(
              achievement.emoji,
              style: const TextStyle(fontSize: 22),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            achievement.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.primary : AppColors.onSurfaceMuted,
            ),
          ),
          Text(
            earned
                ? '${achievement.threshold}+'
                : '$cansCount/${achievement.threshold}',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.onSurfaceFaint,
            ),
          ),
        ],
      ),
    );
  }
}
