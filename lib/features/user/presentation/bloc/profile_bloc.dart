import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/username_validation_result.dart';
import '../../domain/usecases/ensure_user_document.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/update_username.dart';
import '../../domain/usecases/validate_username.dart';
import '../../domain/usecases/watch_user.dart';

part 'profile_event.dart';
part 'profile_state.dart';

/// Управляет состоянием экрана профиля текущего пользователя.
///
/// Подписан на real-time стрим Firestore-документа `users/{uid}` через
/// `WatchUser` и идемпотентно создаёт документ при первом запуске
/// (`EnsureUserDocument`). Сохранение правок идёт через `UpdateProfile`.
@injectable
class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  ProfileBloc(
    this._ensureUserDocument,
    this._watchUser,
    this._updateProfile,
    this._validateUsername,
    this._updateUsername,
  ) : super(const ProfileState.initial()) {
    on<ProfileSubscribeRequested>(_onSubscribeRequested);
    on<ProfileEditSubmitted>(_onEditSubmitted);
    on<ProfileResetRequested>(_onResetRequested);
    on<_ProfileSnapshotReceived>(_onSnapshotReceived);
    on<ProfileUsernameChanged>(
      _onUsernameChanged,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );
    on<ProfileUsernameValidationRequested>(_onUsernameValidationRequested);
    on<ProfileSaveRequested>(_onSaveRequested);
  }

  final EnsureUserDocument _ensureUserDocument;
  final WatchUser _watchUser;
  final UpdateProfile _updateProfile;
  final ValidateUsername _validateUsername;
  final UpdateUsername _updateUsername;

  StreamSubscription<Either<Failure, UserProfile?>>? _profileSubscription;
  String? _currentUserId;

  /// Debounce transformer для username валидации
  EventTransformer<T> _debounce<T>(Duration duration) {
    return (events, mapper) => events.debounce(duration).switchMap(mapper);
  }

  Future<void> _onSubscribeRequested(
    ProfileSubscribeRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final authUser = event.authUser;

    // Если уже подписаны на этого же пользователя — ничего не делаем.
    if (_currentUserId == authUser.id && state.profile != null) {
      return;
    }
    _currentUserId = authUser.id;

    emit(state.copyWith(status: ProfileStatus.loading, clearError: true));

    final ensureResult = await _ensureUserDocument(
      EnsureUserDocumentParams(
        userId: authUser.id,
        email: authUser.email,
        displayName: _safeDisplayName(authUser),
        photoUrl: authUser.photoUrl,
      ),
    );

    final UserProfile? bootstrapped = ensureResult.fold((failure) {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить профиль',
        ),
      );
      return null;
    }, (profile) => profile);

    if (bootstrapped == null) return;

    emit(state.copyWith(status: ProfileStatus.ready, profile: bootstrapped));

    await _profileSubscription?.cancel();
    _profileSubscription = _watchUser(
      authUser.id,
    ).listen((result) => add(_ProfileSnapshotReceived(result)));
  }

  void _onSnapshotReceived(
    _ProfileSnapshotReceived event,
    Emitter<ProfileState> emit,
  ) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: failure.message ?? 'Не удалось обновить профиль',
        ),
      ),
      (profile) {
        if (profile == null) {
          // Документ удалён — отписываемся.
          emit(const ProfileState.initial());
          _profileSubscription?.cancel();
          _profileSubscription = null;
          _currentUserId = null;
        } else {
          emit(
            state.copyWith(
              status: ProfileStatus.ready,
              profile: profile,
              clearError: true,
            ),
          );
        }
      },
    );
  }

  Future<void> _onEditSubmitted(
    ProfileEditSubmitted event,
    Emitter<ProfileState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Профиль ещё не загружен',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ProfileStatus.saving, clearError: true));

    final result = await _updateProfile(
      UpdateProfileParams(
        userId: userId,
        displayName: event.displayName,
        bio: event.bio,
        photoUrl: event.photoUrl,
      ),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: failure.message ?? 'Не удалось сохранить профиль',
        ),
      ),
      (_) =>
          emit(state.copyWith(status: ProfileStatus.ready, clearError: true)),
    );
  }

  Future<void> _onResetRequested(
    ProfileResetRequested event,
    Emitter<ProfileState> emit,
  ) async {
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    _currentUserId = null;
    emit(const ProfileState.initial());
  }

  Future<void> _onUsernameChanged(
    ProfileUsernameChanged event,
    Emitter<ProfileState> emit,
  ) async {
    // Debounced валидация username
    add(ProfileUsernameValidationRequested(event.username));
  }

  Future<void> _onUsernameValidationRequested(
    ProfileUsernameValidationRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) return;

    emit(state.copyWith(isValidatingUsername: true, clearValidation: true));

    final result = await _validateUsername(
      ValidateUsernameParams(username: event.username, userId: userId),
    );

    result.fold(
      (failure) => emit(
        state.copyWith(
          isValidatingUsername: false,
          usernameValidation: UsernameValidationResult.invalid(
            failure.message ?? 'Ошибка валидации',
          ),
        ),
      ),
      (validationResult) => emit(
        state.copyWith(
          isValidatingUsername: false,
          usernameValidation: validationResult,
        ),
      ),
    );
  }

  Future<void> _onSaveRequested(
    ProfileSaveRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final userId = _currentUserId;
    if (userId == null) {
      emit(
        state.copyWith(
          status: ProfileStatus.error,
          errorMessage: 'Профиль ещё не загружен',
        ),
      );
      return;
    }

    emit(state.copyWith(status: ProfileStatus.saving, clearError: true));

    // Если username изменился, обновляем его отдельно
    if (event.username != null &&
        event.username!.isNotEmpty &&
        event.username != state.profile?.username) {
      final usernameResult = await _updateUsername(
        UpdateUsernameParams(userId: userId, newUsername: event.username!),
      );

      final usernameError = usernameResult.fold(
        (failure) => failure.message ?? 'Не удалось обновить username',
        (_) => null,
      );

      if (usernameError != null) {
        emit(
          state.copyWith(
            status: ProfileStatus.error,
            errorMessage: usernameError,
          ),
        );
        return;
      }
    }

    // Обновляем остальные поля профиля
    if (event.displayName != null ||
        event.bio != null ||
        event.photoUrl != null) {
      final result = await _updateProfile(
        UpdateProfileParams(
          userId: userId,
          displayName: event.displayName,
          bio: event.bio,
          photoUrl: event.photoUrl,
        ),
      );

      result.fold(
        (failure) => emit(
          state.copyWith(
            status: ProfileStatus.error,
            errorMessage: failure.message ?? 'Не удалось сохранить профиль',
          ),
        ),
        (_) =>
            emit(state.copyWith(status: ProfileStatus.ready, clearError: true)),
      );
    } else {
      emit(state.copyWith(status: ProfileStatus.ready, clearError: true));
    }
  }

  static String _safeDisplayName(AuthUser user) {
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      return user.displayName!.trim();
    }
    if (user.email.isNotEmpty) return user.email.split('@').first;
    return 'Коллекционер';
  }

  @override
  Future<void> close() async {
    await _profileSubscription?.cancel();
    return super.close();
  }
}
