import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../barcode/data/models/barcode_dto.dart';
import '../../../barcode/domain/entities/barcode.dart' as barcode_entity;
import '../../../barcode/domain/usecases/lookup_barcode.dart';
import '../../../barcode/presentation/pages/barcode_scanner_page.dart';
import '../../../brand/domain/entities/brand.dart';
import '../../../brand/domain/usecases/ensure_brand.dart';
import '../../../brand/presentation/widgets/brand_picker_sheet.dart';
import '../../../flavor/presentation/widgets/flavor_picker_sheet.dart';
import '../../../group/domain/entities/group.dart';
import '../../../group/domain/usecases/watch_my_groups.dart';
import '../../domain/entities/drink_type.dart';
import '../bloc/create_post_bloc.dart';
import '../widgets/rating_widgets.dart';
import 'square_camera_page.dart';

/// Экран создания поста-«банки».
///
/// Принимает опциональные `groupId` / `groupName` (когда пользователь
/// открыл создание из конкретной группы) и пробрасывает их в
/// `CreatePostInitialized`.
class CreatePostPage extends StatelessWidget {
  const CreatePostPage({super.key, this.groupId, this.groupName});

  final String? groupId;
  final String? groupName;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreatePostBloc>(
      create: (_) => sl<CreatePostBloc>(),
      child: _CreatePostView(groupId: groupId, groupName: groupName),
    );
  }
}

class _CreatePostView extends StatefulWidget {
  const _CreatePostView({this.groupId, this.groupName});

  final String? groupId;
  final String? groupName;

  @override
  State<_CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<_CreatePostView> {
  final _formKey = GlobalKey<FormState>();
  final _drinkNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _storeController = TextEditingController();
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthBloc>().state.user;
    if (user != null) {
      context.read<CreatePostBloc>().add(
        CreatePostInitialized(
          authorId: user.id,
          authorName: (user.displayName?.isNotEmpty ?? false)
              ? user.displayName!
              : user.email,
          authorPhotoUrl: user.photoUrl,
          groupId: widget.groupId,
          groupName: widget.groupName,
        ),
      );
    }
  }

  @override
  void dispose() {
    _drinkNameController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _storeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickBrand() async {
    final picked = await BrandPickerSheet.show(context);
    if (!mounted || picked == null) return;
    Brand brand = picked;
    if (brand.id.isEmpty) {
      // Новый бренд — создаём документ через EnsureBrand.
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
    context.read<CreatePostBloc>().add(
      CreatePostBrandSelected(brandId: brand.id, brandName: brand.name),
    );
  }

  Future<void> _pickFlavor(String brandId, String brandName) async {
    final picked = await FlavorPickerSheet.show(
      context,
      brandId: brandId,
      brandName: brandName,
    );
    if (!mounted || picked == null) return;
    context.read<CreatePostBloc>().add(
      CreatePostFlavorSelected(flavorId: picked.id, flavorName: picked.name),
    );
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (!mounted || code == null || code.isEmpty) return;
    final normalized = BarcodeDto.normalize(code);
    if (normalized.isEmpty) return;

    final lookup = await sl<LookupBarcode>().call(normalized);
    if (!mounted) return;
    final barcode_entity.Barcode? matched = lookup.fold((_) => null, (b) => b);

    if (matched != null) {
      // Заполняем только пустое поле: введённое пользователем не трогаем
      // (тот же напиток может продаваться под разными кодами в разных
      // странах — код просто привязывается к посту).
      final hadName = _drinkNameController.text.trim().isNotEmpty;
      if (!hadName) _drinkNameController.text = matched.drinkName;
      context.read<CreatePostBloc>().add(
        CreatePostBarcodeMatched(
          code: normalized,
          drinkName: matched.drinkName,
          brandId: matched.brandId,
          brandName: matched.brandName,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            hadName
                ? 'Код привязан. В базе он значится как «${matched.drinkName}»'
                : 'Узнал банку: ${matched.drinkName}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      context.read<CreatePostBloc>().add(
        CreatePostBarcodeUnknown(code: normalized),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Новый штрих-код. Заполни данные и опубликуй — запомним.',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 100);
    if (!mounted || picked.isEmpty) return;
    context.read<CreatePostBloc>().add(
      CreatePostPhotosPicked(picked.map((x) => File(x.path)).toList()),
    );
  }

  Future<void> _capturePhoto() async {
    // Открываем встроенную квадратную камеру: снимок сразу 1:1.
    if (context.read<CreatePostBloc>().state.pickedFiles.length >= 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Максимум 6 фотографий')));
      return;
    }
    final file = await Navigator.of(
      context,
    ).push<File>(MaterialPageRoute(builder: (_) => const SquareCameraPage()));
    if (!mounted || file == null) return;
    context.read<CreatePostBloc>().add(CreatePostPhotosPicked([file]));
  }

  void _showPermissionDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Требуется доступ к камере'),
        content: const Text(
          'Для съёмки фото банки приложению нужен доступ к камере. '
          'Пожалуйста, предоставьте разрешение в настройках.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: const Text('Открыть настройки'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFoundDate(DateTime current) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (!mounted || picked == null) return;
    context.read<CreatePostBloc>().add(CreatePostFoundDateChanged(picked));
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    context.read<CreatePostBloc>().add(const CreatePostSubmitted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Новая банка')),
      body: BlocConsumer<CreatePostBloc, CreatePostState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (state.status == CreatePostStatus.created &&
              state.createdPostId != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Пост создан')));
            context.read<CreatePostBloc>().add(
              const CreatePostCreationAcknowledged(),
            );
            // Лента и детальный экран — Sprint 9; пока возвращаемся назад.
            context.canPop()
                ? context.pop()
                : context.goNamed(AppRoutes.homeName);
            return;
          }
          if (state.status == CreatePostStatus.error &&
              state.errorMessage != null) {
            // Диалог настроек показываем только для отказа в доступе к камере;
            // прочие ошибки (в т.ч. Firestore permission-denied) — снекбаром.
            if (state.errorMessage!.toLowerCase().contains('камер')) {
              _showPermissionDialog(context);
            } else {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          }
        },
        builder: (context, state) {
          final foundDate = state.foundDate ?? DateTime.now();
          final isBusy = state.isBusy;
          return AbsorbPointer(
            absorbing: isBusy,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Скан — первый шаг: идентифицируем банку, дальше
                    // всё заполнится само (если код уже есть в базе).
                    _BarcodeField(
                      barcode: state.barcode,
                      contributePending: state.barcodeContribute,
                      enabled: !isBusy,
                      onScan: _scanBarcode,
                      onClear: () => context.read<CreatePostBloc>().add(
                        const CreatePostBarcodeCleared(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _PhotoGrid(
                      files: state.pickedFiles,
                      onAdd: _pickPhotos,
                      onCamera: _capturePhoto,
                      onRemove: (index) => context.read<CreatePostBloc>().add(
                        CreatePostPhotoRemoved(index),
                      ),
                      busy: isBusy,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _drinkNameController,
                      enabled: !isBusy,
                      decoration: const InputDecoration(
                        labelText: 'Название поста',
                        hintText: 'Например, «Monster Energy Яблоко»',
                      ),
                      onChanged: (v) => context.read<CreatePostBloc>().add(
                        CreatePostDrinkNameChanged(v),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().length < 2) {
                          return 'Минимум 2 символа';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _BrandField(
                      brandName: state.brandName,
                      enabled: !isBusy,
                      onTap: _pickBrand,
                      onClear: () => context.read<CreatePostBloc>().add(
                        const CreatePostBrandCleared(),
                      ),
                    ),
                    if (state.brandId != null && state.brandId!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _FlavorField(
                        flavorName: state.flavorName,
                        enabled: !isBusy,
                        onTap: () =>
                            _pickFlavor(state.brandId!, state.brandName),
                        onClear: () => context.read<CreatePostBloc>().add(
                          const CreatePostFlavorCleared(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _FoundDateField(
                      date: foundDate,
                      onTap: () => _pickFoundDate(foundDate),
                    ),
                    const SizedBox(height: 16),
                    _StorePriceFields(
                      storeController: _storeController,
                      priceController: _priceController,
                      enabled: !isBusy,
                    ),
                    const SizedBox(height: 24),
                    RatingEditor(
                      enabled: state.isRated,
                      rating: state.ratingDraft,
                      onEnabledChanged: (v) => context
                          .read<CreatePostBloc>()
                          .add(CreatePostRatingEnabled(v)),
                      onChanged: (r) => context.read<CreatePostBloc>().add(
                        CreatePostRatingChanged(r),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _DrinkTypeSelector(
                      value: state.drinkType,
                      onChanged: (t) => context.read<CreatePostBloc>().add(
                        CreatePostDrinkTypeChanged(t),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _TagsField(
                      controller: _tagsController,
                      tags: state.tags,
                      onAdd: (tag) {
                        final next = [...state.tags, tag];
                        context.read<CreatePostBloc>().add(
                          CreatePostTagsChanged(next),
                        );
                      },
                      onRemove: (tag) {
                        final next = [...state.tags]..remove(tag);
                        context.read<CreatePostBloc>().add(
                          CreatePostTagsChanged(next),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !isBusy,
                      maxLines: 4,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Отзыв / впечатления (опционально)',
                        hintText: 'Каков на вкус? Стоит ли брать ещё?',
                      ),
                      onChanged: (v) => context.read<CreatePostBloc>().add(
                        CreatePostDescriptionChanged(v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GroupSelector(
                      groupId: state.groupId,
                      groupName: state.groupName,
                      isAutoSelected: state.isGroupAutoSelected,
                    ),
                    const SizedBox(height: 24),
                    if (state.isUploading)
                      _UploadProgress(
                        uploaded: state.uploadedCount,
                        total: state.totalCount,
                      ),
                    if (state.isCreating)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    FilledButton(
                      onPressed: state.canSubmit ? _submit : null,
                      child: Text(isBusy ? 'Создаём…' : 'Опубликовать банку'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.files,
    required this.onAdd,
    required this.onCamera,
    required this.onRemove,
    required this.busy,
  });

  final List<File> files;
  final VoidCallback onAdd;
  final VoidCallback onCamera;
  final void Function(int) onRemove;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Фото банки (до 6)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: files.length + 2, // +2 для кнопок "Добавить" и "Камера"
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == files.length) {
                return _AddPhotoTile(onTap: busy ? null : onAdd);
              }
              if (i == files.length + 1) {
                return _CameraTile(onTap: busy ? null : onCamera);
              }
              return _PhotoTile(
                file: files[i],
                onRemove: busy ? null : () => onRemove(i),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.add_a_photo_outlined,
          color: AppColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.outline),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.camera_alt_outlined,
          color: AppColors.onSurfaceMuted,
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.file, this.onRemove});
  final File file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, width: 100, height: 100, fit: BoxFit.cover),
        ),
        if (onRemove != null)
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}

class _BarcodeField extends StatelessWidget {
  const _BarcodeField({
    required this.barcode,
    required this.contributePending,
    required this.enabled,
    required this.onScan,
    required this.onClear,
  });

  final String? barcode;
  final bool contributePending;
  final bool enabled;
  final VoidCallback onScan;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCode = barcode != null && barcode!.isNotEmpty;
    return InkWell(
      onTap: enabled ? onScan : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Штрих-код (опционально)',
          helperText: hasCode
              ? (contributePending
                    ? 'Новый код — сохраним в общую базу для других пользователей'
                    : 'Код найден в базе — данные заполнены автоматически')
              : 'Отсканируй штрих-код для автозаполнения. Помогает другим пользователям быстрее добавлять такие же банки.',
          helperMaxLines: 3,
          suffixIcon: hasCode
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: enabled ? onClear : null,
                )
              : const Icon(
                  Icons.qr_code_scanner,
                  color: AppColors.onSurfaceMuted,
                ),
        ),
        child: Row(
          children: [
            Icon(
              hasCode
                  ? Icons.check_circle_outline
                  : Icons.qr_code_scanner_outlined,
              size: 18,
              color: hasCode ? AppColors.primary : AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasCode ? barcode! : 'Сканировать штрих-код',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: hasCode ? null : AppColors.onSurfaceMuted,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandField extends StatelessWidget {
  const _BrandField({
    required this.brandName,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final String brandName;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isEmpty = brandName.isEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Бренд (опционально)',
          suffixIcon: isEmpty
              ? const Icon(Icons.expand_more, color: AppColors.onSurfaceMuted)
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: enabled ? onClear : null,
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
                isEmpty ? 'Выбрать бренд' : brandName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isEmpty ? AppColors.onSurfaceMuted : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FlavorField extends StatelessWidget {
  const _FlavorField({
    required this.flavorName,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final String flavorName;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isEmpty = flavorName.isEmpty;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Вкус (опционально)',
          helperText: isEmpty ? 'Выберите вкус для этого бренда' : null,
          suffixIcon: isEmpty
              ? const Icon(Icons.expand_more, color: AppColors.onSurfaceMuted)
              : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: enabled ? onClear : null,
                ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.icecream_outlined,
              size: 18,
              color: AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isEmpty ? 'Выбрать вкус' : flavorName,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isEmpty ? AppColors.onSurfaceMuted : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoundDateField extends StatelessWidget {
  const _FoundDateField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatted = DateFormat('d MMMM yyyy', 'ru_RU').format(date);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: const InputDecoration(labelText: 'Дата находки'),
        child: Row(
          children: [
            const Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: AppColors.onSurfaceMuted,
            ),
            const SizedBox(width: 8),
            Text(formatted, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _DrinkTypeSelector extends StatelessWidget {
  const _DrinkTypeSelector({required this.value, required this.onChanged});

  final DrinkType value;
  final ValueChanged<DrinkType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Тип напитка', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final type in DrinkType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: type == value,
                onSelected: (_) => onChanged(type),
              ),
          ],
        ),
      ],
    );
  }
}

class _TagsField extends StatelessWidget {
  const _TagsField({
    required this.controller,
    required this.tags,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> tags;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  void _commit() {
    final raw = controller.text.trim().toLowerCase();
    if (raw.isEmpty) return;
    if (tags.contains(raw)) {
      controller.clear();
      return;
    }
    onAdd(raw);
    controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Теги (опционально)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          'Помогают находить похожие банки. Например: лимитка, зима2024, редкая',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zа-я0-9]')),
          ],
          decoration: const InputDecoration(
            hintText: 'Добавь тег и нажми Enter',
            prefixIcon: Icon(Icons.local_offer_outlined, size: 18),
          ),
          onSubmitted: (_) => _commit(),
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in tags)
                Chip(label: Text(t), onDeleted: () => onRemove(t)),
            ],
          ),
        ],
      ],
    );
  }
}

/// «Где купил» + «Цена» — опциональные поля, питающие карточку напитка
/// (статистика магазинов и средняя цена).
class _StorePriceFields extends StatelessWidget {
  const _StorePriceFields({
    required this.storeController,
    required this.priceController,
    required this.enabled,
  });

  final TextEditingController storeController;
  final TextEditingController priceController;
  final bool enabled;

  static const List<String> _suggestions = [
    'Пятёрочка',
    'Магнит',
    'Лента',
    'Красное&Белое',
    'ВкусВилл',
    'Ozon',
    'WB',
    'Из-за границы',
  ];

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CreatePostBloc>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: storeController,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: 'Где купил (опц.)',
                  prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                ),
                onChanged: (v) => bloc.add(CreatePostStoreChanged(v)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: priceController,
                enabled: enabled,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Цена, ₽ (опц.)'),
                onChanged: (v) => bloc.add(
                  CreatePostPriceChanged(
                    double.tryParse(v.replaceAll(',', '.')),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final parsed = double.tryParse(v.replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return 'Число';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final s in _suggestions)
              ActionChip(
                label: Text(s, style: const TextStyle(fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: enabled
                    ? () {
                        storeController.text = s;
                        bloc.add(CreatePostStoreChanged(s));
                      }
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({
    this.groupId,
    this.groupName,
    this.isAutoSelected = false,
  });

  final String? groupId;
  final String? groupName;
  final bool isAutoSelected;

  Future<void> _pick(BuildContext context) async {
    final user = context.read<AuthBloc>().state.user;
    if (user == null) return;
    final selected = await showModalBottomSheet<_GroupSelection>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (_) => _GroupPickerSheet(userId: user.id),
    );
    if (!context.mounted || selected == null) return;
    context.read<CreatePostBloc>().add(
      CreatePostGroupChanged(
        groupId: selected.cleared ? null : selected.id,
        groupName: selected.cleared ? null : selected.name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasGroup = groupId != null;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.groups_outlined),
      title: Text(hasGroup ? groupName ?? 'Группа' : 'Без группы'),
      subtitle: Text(
        hasGroup
            ? isAutoSelected
                  ? 'Автовыбор · Пост попадёт в ленту этой группы'
                  : 'Пост попадёт в ленту этой группы'
            : 'Можно опубликовать без группы',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _pick(context),
    );
  }
}

class _GroupSelection {
  const _GroupSelection({this.id, this.name, this.cleared = false});
  final String? id;
  final String? name;
  final bool cleared;
}

class _GroupPickerSheet extends StatelessWidget {
  const _GroupPickerSheet({required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder(
        stream: sl<WatchMyGroups>().call(userId),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          // Предлагаем только группы, куда пользователь МОЖЕТ постить:
          // с политикой «только админы» обычный участник группу не выберет.
          final groups = snap.data!
              .fold<List<Group>>((_) => const <Group>[], (g) => g)
              .where((g) => g.canPost(userId))
              .toList(growable: false);
          return ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Без группы'),
                onTap: () => Navigator.of(
                  context,
                ).pop(const _GroupSelection(cleared: true)),
              ),
              const Divider(height: 1),
              if (groups.isEmpty)
                const ListTile(
                  title: Text('Ты ещё не вступил ни в одну группу'),
                  enabled: false,
                ),
              for (final g in groups)
                ListTile(
                  leading: const Icon(Icons.group_outlined),
                  title: Text(g.name),
                  subtitle: Text('${g.membersCount} участников'),
                  onTap: () => Navigator.of(
                    context,
                  ).pop(_GroupSelection(id: g.id, name: g.name)),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _UploadProgress extends StatelessWidget {
  const _UploadProgress({required this.uploaded, required this.total});
  final int uploaded;
  final int total;

  @override
  Widget build(BuildContext context) {
    final fraction = total == 0 ? 0.0 : uploaded / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Загружаем фото $uploaded / $total',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceMuted),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: fraction),
          ),
        ],
      ),
    );
  }
}
