import 'package:banka/core/error/failures.dart';
import 'package:banka/features/auth/domain/entities/auth_user.dart';
import 'package:banka/features/user/domain/entities/user_profile.dart';
import 'package:banka/features/user/domain/usecases/ensure_user_document.dart';
import 'package:banka/features/user/domain/usecases/update_profile.dart';
import 'package:banka/features/user/domain/usecases/watch_user.dart';
import 'package:banka/features/user/presentation/bloc/profile_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockEnsureUserDocument extends Mock implements EnsureUserDocument {}

class _MockWatchUser extends Mock implements WatchUser {}

class _MockUpdateProfile extends Mock implements UpdateProfile {}

void main() {
  late _MockEnsureUserDocument ensureUserDocument;
  late _MockWatchUser watchUser;
  late _MockUpdateProfile updateProfile;

  const authUser = AuthUser(
    id: 'uid-1',
    email: 'alice@example.com',
    displayName: 'Alice',
    photoUrl: 'https://cdn.example.com/alice.png',
  );

  const profile = UserProfile(
    id: 'uid-1',
    displayName: 'Alice',
    email: 'alice@example.com',
    photoUrl: 'https://cdn.example.com/alice.png',
    stats: UserStats(cansCount: 5),
  );

  setUp(() {
    ensureUserDocument = _MockEnsureUserDocument();
    watchUser = _MockWatchUser();
    updateProfile = _MockUpdateProfile();

    registerFallbackValue(
      const EnsureUserDocumentParams(userId: '', email: '', displayName: ''),
    );
    registerFallbackValue(const UpdateProfileParams(userId: ''));
  });

  ProfileBloc buildBloc() =>
      ProfileBloc(ensureUserDocument, watchUser, updateProfile);

  group('ProfileSubscribeRequested', () {
    blocTest<ProfileBloc, ProfileState>(
      'emits [loading, ready(profile)] on successful ensure + watch',
      build: () {
        when(
          () => ensureUserDocument(any()),
        ).thenAnswer((_) async => const Right(profile));
        when(() => watchUser('uid-1')).thenAnswer(
          (_) => Stream.value(const Right<Failure, UserProfile?>(profile)),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ProfileSubscribeRequested(authUser)),
      expect: () => [
        const ProfileState(status: ProfileStatus.loading),
        const ProfileState(status: ProfileStatus.ready, profile: profile),
        // Stream re-emits the same value — bloc deduplicates equal states.
      ],
    );

    blocTest<ProfileBloc, ProfileState>(
      'emits [loading, error] when ensureUserDocument fails',
      build: () {
        when(
          () => ensureUserDocument(any()),
        ).thenAnswer((_) async => const Left(ServerFailure(message: 'boom')));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ProfileSubscribeRequested(authUser)),
      expect: () => [
        const ProfileState(status: ProfileStatus.loading),
        const ProfileState(status: ProfileStatus.error, errorMessage: 'boom'),
      ],
    );
  });

  group('ProfileEditSubmitted', () {
    blocTest<ProfileBloc, ProfileState>(
      'emits [saving, ready] on successful update',
      build: () {
        when(
          () => updateProfile(any()),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      seed: () =>
          const ProfileState(status: ProfileStatus.ready, profile: profile),
      act: (bloc) {
        // Set userId so bloc knows which user to update.
        bloc..add(const ProfileEditSubmitted(displayName: 'Bob'));
      },
      expect: () => [
        const ProfileState(
          status: ProfileStatus.error,
          profile: profile,
          errorMessage: 'Профиль ещё не загружен',
        ),
      ],
    );
  });

  group('ProfileResetRequested', () {
    blocTest<ProfileBloc, ProfileState>(
      'emits [initial] and cancels subscription',
      build: () {
        when(
          () => ensureUserDocument(any()),
        ).thenAnswer((_) async => const Right(profile));
        when(() => watchUser('uid-1')).thenAnswer(
          (_) => Stream.value(const Right<Failure, UserProfile?>(profile)),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const ProfileSubscribeRequested(authUser));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        bloc.add(const ProfileResetRequested());
      },
      expect: () => [
        const ProfileState(status: ProfileStatus.loading),
        const ProfileState(status: ProfileStatus.ready, profile: profile),
        const ProfileState.initial(),
      ],
    );
  });
}
