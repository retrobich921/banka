import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/drink_spec.dart';

/// Блок «О напитке» для алкоголя: крепость, стиль, тара, объём и (под
/// катом) IBU.
///
/// Появляется прямо под выбором типа напитка, а не на отдельном экране —
/// пользователь не теряет контекст формы. Частые значения вынесены в чипы,
/// чтобы заполнялось в пару тапов, а не клавиатурой.
class DrinkSpecEditor extends StatelessWidget {
  const DrinkSpecEditor({
    super.key,
    required this.spec,
    required this.onChanged,
  });

  final DrinkSpec spec;
  final ValueChanged<DrinkSpec> onChanged;

  static const List<double> _abvPresets = [4.5, 5.0, 5.5, 6.0, 8.0];
  static const List<int> _volumePresets = [330, 450, 500, 1000];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('О напитке', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Крепость и стиль видно в ленте и в карточке напитка.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 12),

        // --- Крепость -------------------------------------------------
        const _FieldLabel(text: 'Крепость, %'),
        Row(
          children: [
            SizedBox(
              width: 96,
              child: TextFormField(
                initialValue: spec.abv?.toString() ?? '',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  hintText: '5,4',
                  isDense: true,
                ),
                onChanged: (value) {
                  final parsed = double.tryParse(value.replaceAll(',', '.'));
                  onChanged(spec.copyWith(abv: parsed));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final preset in _abvPresets)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _Chip(
                          label: preset.toStringAsFixed(1).replaceAll('.', ','),
                          selected: spec.abv == preset,
                          onTap: () => onChanged(spec.copyWith(abv: preset)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Стиль ----------------------------------------------------
        const _FieldLabel(text: 'Стиль'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final style in BeerStyle.values)
              _Chip(
                label: style.label,
                selected: spec.style == style,
                onTap: () => onChanged(
                  spec.style == style
                      ? spec.copyWith(style: null)
                      : spec.copyWith(style: style),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // --- Тара и объём ---------------------------------------------
        const _FieldLabel(text: 'Тара'),
        Wrap(
          spacing: 6,
          children: [
            for (final container in DrinkContainer.values)
              _Chip(
                label: container.label,
                selected: spec.container == container,
                onTap: () => onChanged(
                  spec.container == container
                      ? spec.copyWith(container: null)
                      : spec.copyWith(container: container),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        const _FieldLabel(text: 'Объём, мл'),
        Wrap(
          spacing: 6,
          children: [
            for (final volume in _volumePresets)
              _Chip(
                label: volume >= 1000 ? '1 л' : '$volume',
                selected: spec.volumeMl == volume,
                onTap: () => onChanged(
                  spec.volumeMl == volume
                      ? spec.copyWith(volumeMl: null)
                      : spec.copyWith(volumeMl: volume),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // --- IBU (для любителей деталей) ------------------------------
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          shape: const Border(),
          collapsedShape: const Border(),
          title: Text(
            'Горечь, IBU — необязательно',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.onSurfaceMuted,
            ),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 120,
                child: TextFormField(
                  initialValue: spec.ibu?.toString() ?? '',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '45',
                    isDense: true,
                  ),
                  onChanged: (value) =>
                      onChanged(spec.copyWith(ibu: int.tryParse(value))),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.16)
              : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: selected ? AppColors.primary : AppColors.onSurfaceMuted,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
