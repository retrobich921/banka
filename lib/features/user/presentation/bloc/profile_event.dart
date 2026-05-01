part of 'profile_bloc.dart';

/// События `ProfileBloc`.
///
/// Внешние:
/// - [ProfileSubscribeRequested] — старт подписки на профиль текущего auth-юзера
///   (с идемпотентным `ensureUserDocument`).
/// - [ProfileEditSubmitted] — апдейт displayName/bio.
/// - [ProfileResetRequested] — сброс при logout.
///
/// Внутренние (приватные): [_ProfileSnapshotReceived].
sealed class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => const [];
}

/// Старт работы блока: создать `users/{uid}` если его нет и подписаться на
/// real-time стрим профиля.
final class ProfileSubscribeRequested extends ProfileEvent {
  const ProfileSubscribeRequested(this.authUser);

  final AuthUser authUser;

  @override
  List<Object?> get props => [authUser];
}

/// Сохранить изменения профиля. `null` — поле не трогаем; пустая строка —
/// очистить bio.
final class ProfileEditSubmitted extends ProfileEvent {
  const ProfileEditSubmitted({this.displayName, this.bio, this.photoUrl});

  final String? displayName;
  final String? bio;
  final String? photoUrl;

  @override
  List<Object?> get props => [displayName, bio, photoUrl];
}

/// Логически очистить блок (например, при logout) и отписаться от стрима.
final class ProfileResetRequested extends ProfileEvent {
  const ProfileResetRequested();
}

final class _ProfileSnapshotReceived extends ProfileEvent {
  const _ProfileSnapshotReceived(this.result);

  final Either<Failure, UserProfile?> result;

  @override
  List<Object?> get props => [result];
}
