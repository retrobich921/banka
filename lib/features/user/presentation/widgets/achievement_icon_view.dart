import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/achievement.dart';

/// Иконка ачивки. Эмодзи сознательно не используем — они выбиваются из
/// тёмной минималистичной темы и по-разному рисуются на разных прошивках.
IconData achievementIconData(AchievementIcon icon) => switch (icon) {
  AchievementIcon.drink => Icons.local_drink_outlined,
  AchievementIcon.shelf => Icons.inventory_2_outlined,
  AchievementIcon.medal => Icons.military_tech_outlined,
  AchievementIcon.star => Icons.star_outline_rounded,
  AchievementIcon.gem => Icons.diamond_outlined,
  AchievementIcon.crown => Icons.workspace_premium_outlined,
  AchievementIcon.trophy => Icons.emoji_events_outlined,
};

/// Иконка ачивки в двух состояниях: полученная — акцентом, закрытая —
/// приглушённая.
class AchievementIconView extends StatelessWidget {
  const AchievementIconView({
    super.key,
    required this.icon,
    required this.earned,
    this.size = 20,
  });

  final AchievementIcon icon;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      achievementIconData(icon),
      size: size,
      color: earned ? AppColors.primary : AppColors.onSurfaceFaint,
    );
  }
}
