import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/drink_rating.dart';

/// Бейдж итогового балла оценки (X/90), цвет — по величине.
class RatingScoreBadge extends StatelessWidget {
  const RatingScoreBadge({
    super.key,
    required this.score,
    this.compact = false,
  });

  final int score;
  final bool compact;

  Color get _bg {
    if (score >= 70) return AppColors.primary;
    if (score >= 45) return AppColors.primary.withValues(alpha: 0.6);
    return AppColors.surfaceVariant;
  }

  Color get _fg => score >= 45 ? AppColors.onPrimary : AppColors.onSurfaceMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$score',
              style: TextStyle(
                color: _fg,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 13 : 16,
              ),
            ),
            TextSpan(
              text: ' / 90',
              style: TextStyle(
                color: _fg.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
                fontSize: compact ? 10 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Редактор составной оценки: тумблер «Оценить» + пять критериев профиля
/// (1–10) и «Вайб» (множитель) + живой итоговый балл.
///
/// Критерии редактор не знает — берёт их из самой оценки
/// (`DrinkRating.criteria`), поэтому пивной профиль рисуется тем же кодом,
/// что и классический.
class RatingEditor extends StatelessWidget {
  const RatingEditor({
    super.key,
    required this.enabled,
    required this.rating,
    required this.onEnabledChanged,
    required this.onChanged,
  });

  final bool enabled;
  final DrinkRating rating;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<DrinkRating> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Оценка напитка', style: theme.textTheme.titleMedium),
            const Spacer(),
            if (enabled) RatingScoreBadge(score: rating.score, compact: true),
            Switch(value: enabled, onChanged: onEnabledChanged),
          ],
        ),
        if (enabled) ...[
          Text(
            'Критерии 1–10, «Вайб» — множитель. Итог = сумма × (вайб/10) × 1.8.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          for (final criterion in rating.criteria)
            _CriterionSlider(
              label: criterion.label,
              value: criterion.value,
              onChanged: (v) => onChanged(criterion.apply(v)),
            ),
          _CriterionSlider(
            label: 'Вайб (множитель)',
            value: rating.vibe,
            onChanged: (v) => onChanged(rating.withVibe(v)),
          ),
        ],
      ],
    );
  }
}

class _CriterionSlider extends StatelessWidget {
  const _CriterionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: theme.textTheme.bodyMedium),
        ),
        Expanded(
          child: Slider(
            min: 1,
            max: 10,
            divisions: 9,
            value: value.toDouble(),
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
