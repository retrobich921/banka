import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/username_validation_result.dart';
import '../bloc/profile_bloc.dart';

/// Экран редактирования профиля (displayName + bio + username).
///
/// При сохранении отправляет `ProfileSaveRequested` — стрим Firestore
/// автоматически обновит `ProfileState.profile` с новыми данными.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _usernameController;
  final _formKey = GlobalKey<FormState>();
  String? _initialUsername;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileBloc>().state.profile;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _initialUsername = profile?.username;

    // Слушаем изменения username для debounced валидации
    _usernameController.addListener(_onUsernameChanged);
  }

  @override
  void dispose() {
    _usernameController.removeListener(_onUsernameChanged);
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    final username = _usernameController.text.trim();
    if (username.isNotEmpty && username != _initialUsername) {
      context.read<ProfileBloc>().add(ProfileUsernameChanged(username));
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final state = context.read<ProfileBloc>().state;
    final username = _usernameController.text.trim();

    // Проверяем валидацию username, если он изменился
    if (username != _initialUsername && username.isNotEmpty) {
      final validation = state.usernameValidation;
      if (validation == null || !validation.maybeMap(
        valid: (_) => true,
        orElse: () => false,
      )) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Пожалуйста, исправьте ошибки в username'),
            ),
          );
        return;
      }
    }

    context.read<ProfileBloc>().add(
      ProfileSaveRequested(
        displayName: _nameController.text.trim(),
        bio: _bioController.text.trim(),
        username: username.isNotEmpty ? username : null,
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
              // Cooldown warning banner
              BlocBuilder<ProfileBloc, ProfileState>(
                buildWhen: (prev, curr) =>
                    prev.usernameValidation != curr.usernameValidation,
                builder: (context, state) {
                  final validation = state.usernameValidation;
                  if (validation == null) return const SizedBox.shrink();

                  return validation.maybeMap(
                    cooldownActive: (cooldown) {
                      final dateFormat = DateFormat('dd.MM.yyyy');
                      final nextDate = dateFormat.format(cooldown.nextAvailableDate);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFB300).withValues(alpha: 0.1),
                          border: Border.all(
                            color: const Color(0xFFFFB300),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Color(0xFFFFB300),
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Username можно изменить снова после $nextDate',
                                style: const TextStyle(
                                  color: Color(0xFFFFB300),
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
              ),

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

              // Username field with validation
              BlocBuilder<ProfileBloc, ProfileState>(
                buildWhen: (prev, curr) =>
                    prev.usernameValidation != curr.usernameValidation ||
                    prev.isValidatingUsername != curr.isValidatingUsername,
                builder: (context, state) {
                  final validation = state.usernameValidation;
                  final isValidating = state.isValidatingUsername;

                  Widget? suffixIcon;
                  String? errorText;

                  if (isValidating) {
                    suffixIcon = const SizedBox(
                      width: 20,
                      height: 20,
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  } else if (validation != null) {
                    validation.map(
                      valid: (_) {
                        suffixIcon = const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        );
                      },
                      invalid: (invalid) {
                        suffixIcon = const Icon(
                          Icons.error,
                          color: Colors.red,
                        );
                        errorText = invalid.reason;
                      },
                      taken: (_) {
                        suffixIcon = const Icon(
                          Icons.error,
                          color: Colors.red,
                        );
                        errorText = 'Username уже занят';
                      },
                      cooldownActive: (cooldown) {
                        suffixIcon = const Icon(
                          Icons.lock,
                          color: Color(0xFFFFB300),
                        );
                        final dateFormat = DateFormat('dd.MM.yyyy');
                        final nextDate = dateFormat.format(cooldown.nextAvailableDate);
                        errorText = 'Можно изменить после $nextDate';
                      },
                    );
                  }

                  return TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      helperText: '3-20 символов: буквы, цифры, подчёркивание',
                      helperMaxLines: 2,
                      suffixIcon: suffixIcon,
                      errorText: errorText,
                      errorMaxLines: 2,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username не может быть пустым';
                      }
                      return null;
                    },
                  );
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
