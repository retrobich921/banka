import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/profile_bloc.dart';

/// Экран редактирования профиля (displayName + bio).
///
/// При сохранении отправляет `ProfileEditSubmitted` — стрим Firestore
/// автоматически обновит `ProfileState.profile` с новыми данными.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileBloc>().state.profile;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    context.read<ProfileBloc>().add(
      ProfileEditSubmitted(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Редактирование'),
        actions: [
          BlocBuilder<ProfileBloc, ProfileState>(
            buildWhen: (prev, curr) =>
                prev.isSaving != curr.isSaving || prev.status != curr.status,
            builder: (context, state) {
              return TextButton(
                onPressed: state.isSaving ? null : _save,
                child: state.isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Сохранить'),
              );
            },
          ),
        ],
      ),
      body: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) =>
            (prev.isSaving && curr.isReady) ||
            (prev.isSaving && curr.status == ProfileStatus.error),
        listener: (context, state) {
          if (state.isReady) {
            Navigator.of(context).pop();
          } else if (state.status == ProfileStatus.error) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.errorMessage ?? 'Ошибка сохранения'),
                ),
              );
          }
        },
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Имя'),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Имя не может быть пустым';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'О себе',
                  hintText: 'Расскажи о своей коллекции…',
                ),
                maxLines: 3,
                maxLength: 200,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
