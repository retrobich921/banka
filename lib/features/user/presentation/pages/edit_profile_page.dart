import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/username_validation_result.dart';
import '../bloc/profile_bloc.dart';

/// Экран редактирования профиля (аватар-превью + имя + username + bio).
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

  /// Поля уже заполнены данными профиля — повторно не перетираем ввод.
  bool _hydrated = false;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ProfileBloc>();
    final profile = bloc.state.profile;
    _nameController = TextEditingController(text: profile?.displayName ?? '');
    _bioController = TextEditingController(text: profile?.bio ?? '');
    _usernameController = TextEditingController(text: profile?.username ?? '');
    _initialUsername = profile?.username;
    _hydrated = profile != null;

    // Экран открывается пушем маршрута, и у него может оказаться свой
    // ProfileBloc (тот, что во вкладке профиля, сюда не достаёт) — тогда
    // подписываемся сами, иначе поля останутся пустыми, а сохранение
    // молча ничего не сделает: блок не знает userId.
    if (profile == null) {
      final user = context.read<AuthBloc>().state.user;
      if (user != null) bloc.add(ProfileSubscribeRequested(user));
    }

    // Слушаем изменения username для debounced валидации
    _usernameController.addListener(_onUsernameChanged);
  }

  /// Заполняет поля, когда профиль приехал из стрима.
  void _hydrate(UserProfile profile) {
    if (_hydrated) return;
    _hydrated = true;
    _nameController.text = profile.displayName;
    _bioController.text = profile.bio ?? '';
    _usernameController.removeListener(_onUsernameChanged);
    _usernameController.text = profile.username;
    _usernameController.addListener(_onUsernameChanged);
    _initialUsername = profile.username;
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
    // Клавиатуру убираем сразу — иначе снекбар об ошибке прячется за ней.
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final state = context.read<ProfileBloc>().state;
    final username = _usernameController.text.trim();

    // Проверяем валидацию username, если он изменился
    if (username != _initialUsername && username.isNotEmpty) {
      final validation = state.usernameValidation;
      if (validation == null ||
          !validation.maybeMap(valid: (_) => true, orElse: () => false)) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text(
                'Проверьте username — он занят или '
                'ещё проверяется',
              ),
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
    final photoUrl = context.select<ProfileBloc, String?>(
      (bloc) => bloc.state.profile?.photoUrl,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Редактирование')),
      body: BlocListener<ProfileBloc, ProfileState>(
        listenWhen: (prev, curr) =>
            (prev.isSaving && curr.isReady) ||
            (prev.isSaving && curr.status == ProfileStatus.error) ||
            (prev.profile == null && curr.profile != null),
        listener: (context, state) {
          final profile = state.profile;
          if (!_hydrated && profile != null) {
            _hydrate(profile);
            return;
          }
          if (state.isReady) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(const SnackBar(content: Text('Профиль обновлён')));
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
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Center(child: _AvatarPreview(photoUrl: photoUrl)),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Фото подтягивается из Google-аккаунта',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceFaint,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              const _CooldownBanner(),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Имя',
                  helperText: 'Видно другим коллекционерам',
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 40,
                buildCounter: _hiddenCounter,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Имя не может быть пустым';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              _UsernameField(controller: _usernameController),
              const SizedBox(height: 16),

              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'О себе',
                  hintText: 'Что собираете, чем гордитесь…',
                  alignLabelWithHint: true,
                ),
                minLines: 3,
                maxLines: 5,
                maxLength: 200,
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 24),

              BlocBuilder<ProfileBloc, ProfileState>(
                buildWhen: (prev, curr) => prev.isSaving != curr.isSaving,
                builder: (context, state) => FilledButton(
                  onPressed: state.isSaving ? null : _save,
                  child: state.isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Счётчик символов под полем скрываем — он шумит, ограничение и так
  /// не даёт ввести лишнее.
  static Widget? _hiddenCounter(
    BuildContext context, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null && photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 44,
        backgroundColor: AppColors.surfaceVariant,
        backgroundImage: NetworkImage(photoUrl!),
      );
    }
    return const CircleAvatar(
      radius: 44,
      backgroundColor: AppColors.surfaceVariant,
      child: Icon(
        Icons.account_circle_outlined,
        size: 60,
        color: AppColors.onSurfaceMuted,
      ),
    );
  }
}

/// Плашка «username менялся недавно» — показывается только в cooldown.
class _CooldownBanner extends StatelessWidget {
  const _CooldownBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      buildWhen: (prev, curr) =>
          prev.usernameValidation != curr.usernameValidation,
      builder: (context, state) {
        final validation = state.usernameValidation;
        if (validation == null) return const SizedBox.shrink();

        return validation.maybeMap(
          cooldownActive: (cooldown) {
            final nextDate = DateFormat(
              'dd.MM.yyyy',
            ).format(cooldown.nextAvailableDate);
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Username можно изменить снова после $nextDate',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Поле username: префикс `@`, только допустимые символы (буквы, цифры,
/// подчёркивание) — раскладку и пробелы отсекаем на вводе, а не ошибкой
/// после debounce.
class _UsernameField extends StatelessWidget {
  const _UsernameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      buildWhen: (prev, curr) =>
          prev.usernameValidation != curr.usernameValidation ||
          prev.isValidatingUsername != curr.isValidatingUsername,
      builder: (context, state) {
        final validation = state.usernameValidation;
        Widget? suffixIcon;
        String? errorText;

        if (state.isValidatingUsername) {
          suffixIcon = const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        } else if (validation != null) {
          validation.map(
            valid: (_) {
              suffixIcon = const Icon(
                Icons.check_circle,
                color: AppColors.success,
              );
            },
            invalid: (invalid) {
              suffixIcon = const Icon(Icons.error, color: AppColors.error);
              errorText = invalid.reason;
            },
            taken: (_) {
              suffixIcon = const Icon(Icons.error, color: AppColors.error);
              errorText = 'Username уже занят';
            },
            cooldownActive: (cooldown) {
              suffixIcon = const Icon(Icons.lock, color: AppColors.primary);
              final nextDate = DateFormat(
                'dd.MM.yyyy',
              ).format(cooldown.nextAvailableDate);
              errorText = 'Можно изменить после $nextDate';
            },
          );
        }

        return TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Username',
            prefixText: '@',
            helperText: '3–20 символов: латиница, цифры, подчёркивание',
            helperMaxLines: 2,
            suffixIcon: suffixIcon,
            errorText: errorText,
            errorMaxLines: 2,
          ),
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          maxLength: 20,
          buildCounter:
              (
                context, {
                required currentLength,
                required isFocused,
                required maxLength,
              }) => null,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9_]')),
          ],
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Username не может быть пустым';
            }
            if (value.trim().length < 3) {
              return 'Минимум 3 символа';
            }
            return null;
          },
        );
      },
    );
  }
}
