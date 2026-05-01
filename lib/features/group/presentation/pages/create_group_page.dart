import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/groups_list_bloc.dart';

/// Экран создания группы. После `GroupsListStatus.created` экран сам
/// `pop()`'ится — переход на новый `/groups/:id` делает родительский
/// экран `/groups` через `BlocListener` на `createdGroupId`.
class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = true;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<GroupsListBloc>().add(
      GroupsListCreateRequested(
        name: _nameController.text,
        description: _descriptionController.text,
        isPublic: _isPublic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Новая группа')),
      body: BlocListener<GroupsListBloc, GroupsListState>(
        listenWhen: (prev, curr) =>
            prev.status != curr.status &&
            (curr.status == GroupsListStatus.created ||
                curr.status == GroupsListStatus.error),
        listener: (context, state) {
          if (state.status == GroupsListStatus.created) {
            // Возвращаемся на /groups; туда же придёт createdGroupId,
            // и список сам переключит на новый /groups/:id.
            Navigator.of(context).pop();
            return;
          }
          if (state.status == GroupsListStatus.error &&
              state.errorMessage != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
          }
        },
        child: BlocBuilder<GroupsListBloc, GroupsListState>(
          buildWhen: (prev, curr) => prev.status != curr.status,
          builder: (context, state) {
            final isSubmitting = state.isCreating;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      enabled: !isSubmitting,
                      decoration: const InputDecoration(
                        labelText: 'Название',
                        hintText: 'Например, «Лимитки Monster»',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Введи название';
                        }
                        if (value.trim().length < 3) {
                          return 'Минимум 3 символа';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !isSubmitting,
                      maxLines: 3,
                      maxLength: 280,
                      decoration: const InputDecoration(
                        labelText: 'Описание (опционально)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Публичная'),
                      subtitle: Text(
                        _isPublic
                            ? 'Видна на витрине, любой может вступить'
                            : 'Скрыта; только по прямой ссылке',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.onSurfaceMuted,
                        ),
                      ),
                      value: _isPublic,
                      onChanged: isSubmitting
                          ? null
                          : (value) => setState(() => _isPublic = value),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: isSubmitting ? null : _submit,
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Создать'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
