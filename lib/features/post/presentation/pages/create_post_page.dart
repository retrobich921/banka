import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/di/injector.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../group/domain/entities/group.dart';
import '../../../group/domain/usecases/watch_my_groups.dart';
import '../bloc/create_post_bloc.dart';

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
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

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
    _brandController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 100);
    if (!mounted || picked.isEmpty) return;
    context.read<CreatePostBloc>().add(
      CreatePostPhotosPicked(picked.map((x) => File(x.path)).toList()),
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        builder: (context, state) {
          final foundDate = state.foundDate ?? DateTime.now();
          final isBusy = state.isBusy;
          return AbsorbPointer(
            absorbing: isBusy,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PhotoGrid(
                      files: state.pickedFiles,
                      onAdd: _pickPhotos,
                      onRemove: (index) => context.read<CreatePostBloc>().add(
                        CreatePostPhotoRemoved(index),
                      ),
                      busy: isBusy,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _drinkNameController,
                      enabled: !isBusy,
                      decoration: const InputDecoration(
                        labelText: 'Название напитка',
                        hintText: 'Например, «Monster Energy»',
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
                    TextFormField(
                      controller: _brandController,
                      enabled: !isBusy,
                      decoration: const InputDecoration(
                        labelText: 'Бренд (опционально)',
                        hintText: 'Например, Monster',
                      ),
                      onChanged: (v) => context.read<CreatePostBloc>().add(
                        CreatePostBrandNameChanged(v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FoundDateField(
                      date: foundDate,
                      onTap: () => _pickFoundDate(foundDate),
                    ),
                    const SizedBox(height: 24),
                    _RaritySlider(
                      value: state.rarity,
                      onChanged: (v) => context.read<CreatePostBloc>().add(
                        CreatePostRarityChanged(v),
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
                        labelText: 'Описание (опционально)',
                      ),
                      onChanged: (v) => context.read<CreatePostBloc>().add(
                        CreatePostDescriptionChanged(v),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _GroupSelector(
                      groupId: state.groupId,
                      groupName: state.groupName,
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
    required this.onRemove,
    required this.busy,
  });

  final List<File> files;
  final VoidCallback onAdd;
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
            itemCount: files.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              if (i == files.length) {
                return _AddPhotoTile(onTap: busy ? null : onAdd);
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

class _RaritySlider extends StatelessWidget {
  const _RaritySlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Редкость', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$value / 9',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        Slider(
          min: 1,
          max: 9,
          divisions: 8,
          value: value.toDouble(),
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
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
        Text('Теги', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
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

class _GroupSelector extends StatelessWidget {
  const _GroupSelector({this.groupId, this.groupName});

  final String? groupId;
  final String? groupName;

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
            ? 'Пост попадёт в ленту этой группы'
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
          final groups = snap.data!.fold<List<Group>>(
            (_) => const <Group>[],
            (g) => g,
          );
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
