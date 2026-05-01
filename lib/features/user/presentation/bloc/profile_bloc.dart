import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../../auth/domain/entities/auth_user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/ensure_user_document.dart';
import '../../domain/usecases/update_profile.dart';
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
  ProfileBloc(this._ensureUserDocument, this._watchUser, this._updateProfile)
    : super(const ProfileState.initial()) {
    on<ProfileSubscribeRequested>(_onSubscribeRequested);
    on<ProfileEditSubmitted>(_onEditSubmitted);
    on<ProfileResetRequested>(_onResetRequested);
    on<_ProfileSnapshotReceived>(_onSnapshotReceived);
  }

  final EnsureUserDocument _ensureUserDocument;
  final WatchUser _watchUser;
  final UpdateProfile _updateProfile;

  StreamSubscription<Either<Failure, UserProfile?>>? _profileSubscription;
  String? _currentUserId;

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
