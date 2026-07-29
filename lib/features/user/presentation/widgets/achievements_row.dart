import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/achievement.dart';
import 'achievement_icon_view.dart';

/// Блок ачивок в профиле.
///
/// Показываем ТОЛЬКО полученные ачивки (витрину выбирает пользователь на
/// экране «Достижения») и одну строку прогресса к ближайшей цели. Порог
/// цели (`/100`, `/150`) сознательно не показываем — только текущее число
/// банок и полоса: как только цель взята, она уходит в витрину, а на её
/// месте появляется следующая.
///
/// Символы — иконки, а не эмодзи: эмодзи выбиваются из тёмной темы и
/// по-разному рисуются на разных прошивках.
class AchievementsRow extends StatelessWidget {
  const AchievementsRow({
    super.key,
    required this.cansCount,
    this.pinnedIds = const [],
    this.onOpen,
  });

  final int cansCount;
  final List<String> pinnedIds;

  /// Открыть экран «Достижения». `null` — кнопку не показываем.
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = visibleAchievements(
      cansCount: cansCount,
      pinnedIds: pinnedIds,
    );
    final next = nextAchievement(cansCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Достижения',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onOpen != null)
                TextButton.icon(
                  onPressed: onOpen,
                  icon: const Icon(Icons.emoji_events_outlined, size: 18),
                  label: const Text('Все'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ),
        if (shown.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
            child: Text(
              'Пока ни одной — добавьте первую банку.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceFaint,
              ),
            ),
          )
        else
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: shown.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _EarnedChip(achievement: shown[i]),
            ),
          ),
        if (next != null) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _NextGoal(
              achievement: next,
              cansCount: cansCount,
              progress: nextAchievementProgress(cansCount),
            ),
          ),
        ],
      ],
    );
  }
}

class _EarnedChip extends StatelessWidget {
  const _EarnedChip({required this.achievement});

  final Achievement achievement;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AchievementIconView(icon: achievement.icon, earned: true, size: 16),
          const SizedBox(width: 6),
          Text(
            achievement.title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ближайшая цель: иконка, название и полоса прогресса. Конечное число
/// (порог) не показываем — только текущее количество банок.
class _NextGoal extends StatelessWidget {
  const _NextGoal({
    required this.achievement,
    required this.cansCount,
    required this.progress,
  });

  final Achievement achievement;
  final int cansCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AchievementIconView(
              icon: achievement.icon,
              earned: false,
              size: 16,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Следующая: ${achievement.title}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceMuted,
                ),
              ),
            ),
            Text(
              '$cansCount',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: AppColors.surfaceVariant,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}
