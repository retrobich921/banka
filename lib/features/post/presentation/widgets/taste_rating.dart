import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Звёзды оценки вкуса (только отображение), 1–5. При `rating == 0`
/// ничего не показываем — оценки нет.
class TasteStars extends StatelessWidget {
  const TasteStars({super.key, required this.rating, this.size = 16});

  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (rating <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= rating ? AppColors.primary : AppColors.onSurfaceFaint,
          ),
      ],
    );
  }
}

/// Интерактивный выбор оценки вкуса 1–5. Повторный тап по текущей звезде
/// снимает оценку (0).
class TasteRatingSelector extends StatelessWidget {
  const TasteRatingSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Оценка вкуса', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              value > 0 ? '$value / 5' : 'нет оценки',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: value > 0 ? AppColors.primary : AppColors.onSurfaceMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: () => onChanged(i == value ? 0 : i),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 2),
                constraints: const BoxConstraints(),
                icon: Icon(
                  i <= value
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 36,
                  color: i <= value
                      ? AppColors.primary
                      : AppColors.onSurfaceFaint,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
