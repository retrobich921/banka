import 'package:flutter/material.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../brand/domain/entities/brand.dart';
import '../../../brand/domain/usecases/ensure_brand.dart';
import '../../../brand/presentation/widgets/brand_picker_sheet.dart';
import '../../domain/entities/search_filters.dart';

/// Bottom-sheet редактирования `SearchFilters`.
///
/// Возвращает обновлённые фильтры через `Navigator.pop(filters)`.
/// Доступны: слайдер диапазона редкости (1..9), селектор бренда
/// (`BrandPickerSheet`) и текстовое поле ID группы.
class FiltersSheet extends StatefulWidget {
  const FiltersSheet({super.key, required this.initial});

  final SearchFilters initial;

  @override
  State<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<FiltersSheet> {
  late RangeValues _rarity;
  late TextEditingController _groupId;
  String? _brandId;
  String _brandName = '';

  static const double _rarityMin = 1;
  static const double _rarityMax = 9;

  @override
  void initState() {
    super.initState();
    _rarity = RangeValues(
      (widget.initial.rarityMin ?? _rarityMin.toInt()).toDouble(),
      (widget.initial.rarityMax ?? _rarityMax.toInt()).toDouble(),
    );
    _brandId = widget.initial.brandId;
    _groupId = TextEditingController(text: widget.initial.groupId ?? '');
  }

  @override
  void dispose() {
    _groupId.dispose();
    super.dispose();
  }

  Future<void> _pickBrand() async {
    final picked = await BrandPickerSheet.show(context);
    if (!mounted || picked == null) return;
    Brand brand = picked;
    if (brand.id.isEmpty) {
      final ensured = await sl<EnsureBrand>().call(
        EnsureBrandParams(name: brand.name),
      );
      if (!mounted) return;
      final result = ensured.fold((_) => null, (b) => b);
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось создать бренд')),
        );
        return;
      }
      brand = result;
    }
    setState(() {
      _brandId = brand.id;
      _brandName = brand.name;
    });
  }

  void _clearBrand() {
    setState(() {
      _brandId = null;
      _brandName = '';
    });
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
            InkWell(
              onTap: _pickBrand,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Бренд (опционально)',
                  suffixIcon: _brandId == null
                      ? const Icon(
                          Icons.expand_more,
                          color: AppColors.onSurfaceMuted,
                        )
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: _clearBrand,
                        ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_drink_outlined,
                      size: 18,
                      color: AppColors.onSurfaceMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _brandId == null ? 'Выбрать бренд' : _brandName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: _brandId == null
                              ? AppColors.onSurfaceMuted
                              : null,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
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
                        brandId: _brandId,
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
