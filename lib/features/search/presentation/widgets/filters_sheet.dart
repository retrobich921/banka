import 'package:flutter/material.dart';

import '../../domain/entities/search_filters.dart';

/// Bottom-sheet редактирования `SearchFilters`.
///
/// Возвращает обновлённые фильтры через `Navigator.pop(filters)`.
/// Сейчас доступен слайдер диапазона редкости (1..9) + текстовые поля
/// brandId / groupId. Sprint 13 заменит brandId-инпут на селектор по
/// коллекции `brands`.
class FiltersSheet extends StatefulWidget {
  const FiltersSheet({super.key, required this.initial});

  final SearchFilters initial;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late RangeValues _rarity;
  late TextEditingController _brandId;
  late TextEditingController _groupId;

  static const double _rarityMin = 1;
  static const double _rarityMax = 9;

  @override
  void initState() {
    super.initState();
    _rarity = RangeValues(
      (widget.initial.rarityMin ?? _rarityMin.toInt()).toDouble(),
      (widget.initial.rarityMax ?? _rarityMax.toInt()).toDouble(),
    );
    _brandId = TextEditingController(text: widget.initial.brandId ?? '');
    _groupId = TextEditingController(text: widget.initial.groupId ?? '');
  }

  @override
  void dispose() {
    _brandId.dispose();
    _groupId.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRarityFilter =
        _rarity.start > _rarityMin || _rarity.end < _rarityMax;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Фильтры',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Редкость: ${_rarity.start.round()} — ${_rarity.end.round()}',
              style: theme.textTheme.bodyMedium,
            ),
            RangeSlider(
              min: _rarityMin,
              max: _rarityMax,
              divisions: 8,
              values: _rarity,
              labels: RangeLabels(
                _rarity.start.round().toString(),
                _rarity.end.round().toString(),
              ),
              onChanged: (v) => setState(() => _rarity = v),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _brandId,
              decoration: const InputDecoration(
                labelText: 'ID бренда (опционально)',
                hintText: 'оставь пустым, если без фильтра',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupId,
              decoration: const InputDecoration(
                labelText: 'ID группы (опционально)',
                hintText: 'оставь пустым, если без фильтра',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(const SearchFilters.empty()),
                  child: const Text('Сбросить'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      SearchFilters(
                        rarityMin: hasRarityFilter
                            ? _rarity.start.round()
                            : null,
                        rarityMax: hasRarityFilter ? _rarity.end.round() : null,
                        brandId: _brandId.text.trim().isEmpty
                            ? null
                            : _brandId.text.trim(),
                        groupId: _groupId.text.trim().isEmpty
                            ? null
                            : _groupId.text.trim(),
                      ),
                    );
                  },
                  child: const Text('Применить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
