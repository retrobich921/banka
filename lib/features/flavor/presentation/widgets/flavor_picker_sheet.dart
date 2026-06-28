import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/flavor.dart';
import '../../domain/usecases/create_flavor.dart';
import '../../domain/usecases/watch_flavors.dart';
import '../../../../core/di/injector.dart';

/// Bottom-sheet выбора вкуса для конкретного бренда.
///
/// Возвращает выбранный `Flavor` через `Navigator.pop(flavor)`.
/// Если вкуса нет, можно создать новый через кнопку «Новый вкус».
class FlavorPickerSheet extends StatelessWidget {
  const FlavorPickerSheet({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  final String brandId;
  final String brandName;

  static Future<Flavor?> show(
    BuildContext context, {
    required String brandId,
    required String brandName,
  }) {
    return showModalBottomSheet<Flavor>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FlavorPickerSheet(
        brandId: brandId,
        brandName: brandName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _FlavorPickerView(brandId: brandId, brandName: brandName);
  }
}

class _FlavorPickerView extends StatefulWidget {
  const _FlavorPickerView({
    required this.brandId,
    required this.brandName,
  });

  final String brandId;
  final String brandName;

  @override
  State<_FlavorPickerView> createState() => _FlavorPickerViewState();
}

class _FlavorPickerViewState extends State<_FlavorPickerView> {
  String _query = '';
  bool _isCreating = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          children: [
            Text(
              'Выберите вкус для ${widget.brandName}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 12),
            TextField(
              autofocus: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Найти вкус…',
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isCreating ? null : () => _onCreatePressed(context),
                icon: const Icon(Icons.add),
                label: const Text('Новый вкус'),
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceVariant),
            Expanded(
              child: StreamBuilder(
                stream: sl<WatchFlavors>().call(widget.brandId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Ошибка: ${snapshot.error}',
                        style: const TextStyle(color: AppColors.error),
                      ),
                    );
                  }
                  final result = snapshot.data;
                  if (result == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final flavors = result.fold<List<Flavor>>(
                    (_) => const <Flavor>[],
                    (list) => list,
                  );
                  final filtered = _query.isEmpty
                      ? flavors
                      : flavors
                          .where((f) => f.name.toLowerCase().contains(_query))
                          .toList(growable: false);
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Вкусов пока нет. Создайте первый!'),
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
                      final flavor = filtered[i];
                      return ListTile(
                        leading: const Icon(
                          Icons.local_drink_outlined,
                          color: AppColors.primary,
                        ),
                        title: Text(flavor.name),
                        onTap: () => Navigator.of(context).pop(flavor),
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
        title: const Text('Новый вкус'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Название вкуса'),
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

    setState(() => _isCreating = true);

    final result = await sl<CreateFlavor>().call(
      CreateFlavorParams(brandId: widget.brandId, name: name),
    );

    if (!context.mounted) return;

    setState(() => _isCreating = false);

    final flavor = result.fold((_) => null, (f) => f);
    if (flavor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать вкус')),
      );
      return;
    }

    Navigator.of(context).pop(flavor);
  }
}
