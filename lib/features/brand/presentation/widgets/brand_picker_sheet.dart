import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/brand.dart';
import '../bloc/brands_bloc.dart';
import 'brand_tile.dart';

/// Bottom-sheet выбора бренда из коллекции `brands`.
///
/// Возвращает выбранный `Brand` через `Navigator.pop(brand)`. Кроме
/// существующих брендов есть кнопка «Новый бренд», открывающая диалог
/// ввода имени — pop возвращает `Brand` с пустым `id` (его создаст
/// `EnsureBrand` usecase в форме создания поста).
///
/// Sprint 13 — простая поисковая фильтрация по `name` (case-insensitive)
/// прямо на клиенте: брендов мало.
class BrandPickerSheet extends StatelessWidget {
  const BrandPickerSheet({super.key, this.allowCreate = true});

  final bool allowCreate;

  static Future<Brand?> show(BuildContext context, {bool allowCreate = true}) {
    return showModalBottomSheet<Brand>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BrandPickerSheet(allowCreate: allowCreate),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BrandsBloc>(
      create: (_) => sl<BrandsBloc>()..add(const BrandsSubscribeRequested()),
      child: _BrandPickerView(allowCreate: allowCreate),
    );
  }
}

class _BrandPickerView extends StatefulWidget {
  const _BrandPickerView({required this.allowCreate});

  final bool allowCreate;

  @override
  State<_BrandPickerView> createState() => _BrandPickerViewState();
}

class _BrandPickerViewState extends State<_BrandPickerView> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            const Text(
              'Выберите бренд',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Найти бренд…',
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            if (widget.allowCreate)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _onCreatePressed(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Новый бренд'),
                ),
              ),
            const Divider(height: 1, color: AppColors.surfaceVariant),
            Expanded(
              child: BlocBuilder<BrandsBloc, BrandsState>(
                builder: (context, state) {
                  if (state.isLoading || state.status == BrandsStatus.initial) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state.hasError) {
                    return Center(
                      child: Text(
                        state.errorMessage ?? 'Ошибка',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    );
                  }
                  final filtered = _query.isEmpty
                      ? state.brands
                      : state.brands
                            .where((b) => b.name.toLowerCase().contains(_query))
                            .toList(growable: false);
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Ничего не найдено'),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      color: AppColors.surfaceVariant,
                    ),
                    itemBuilder: (_, i) {
                      final brand = filtered[i];
                      return BrandTile(
                        brand: brand,
                        onTap: () => Navigator.of(context).pop(brand),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onCreatePressed(BuildContext context) async {
    final controller = TextEditingController(text: _query);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Новый бренд'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Название бренда'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (!context.mounted || name == null || name.isEmpty) return;
    // Возвращаем «черновой» Brand с пустым id — вызывающий код
    // (CreatePost) сам сделает `EnsureBrand`, чтобы атомарно
    // привязать постовый brandId к существующему / новому документу.
    Navigator.of(context).pop(Brand(id: '', name: name, slug: ''));
  }
}
