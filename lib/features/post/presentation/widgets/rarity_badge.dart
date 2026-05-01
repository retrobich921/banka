import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Бейдж редкости 1–9.
///
/// Шкала визуализирует значение через насыщенность янтарного: 1–3 →
/// приглушённое, 4–6 → стандартное, 7–9 → яркое + жирное.
class RarityBadge extends StatelessWidget {
  const RarityBadge({super.key, required this.rarity, this.size = 30});

  final int rarity;
  final double size;

  Color get _bg {
    if (rarity >= 7) return AppColors.primary;
    if (rarity >= 4) return AppColors.primary.withValues(alpha: 0.6);
    return AppColors.surfaceVariant;
  }

  Color get _fg {
    if (rarity >= 4) return AppColors.onPrimary;
    return AppColors.onSurfaceMuted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: _bg, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        '$rarity',
        style: TextStyle(
          color: _fg,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.42,
        ),
      ),
    );
  }
}
