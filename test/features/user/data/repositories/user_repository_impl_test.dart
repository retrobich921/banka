import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/user/data/datasources/user_remote_data_source.dart';
import 'package:banka/features/user/data/repositories/user_repository_impl.dart';
import 'package:banka/features/user/domain/entities/user_profile.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockUserRemoteDataSource extends Mock implements UserRemoteDataSource {}

void main() {
  late _MockUserRemoteDataSource remote;
  late UserRepositoryImpl repository;

  const userId = 'uid-1';
  const profile = UserProfile(
    id: userId,
    displayName: 'Alice',
    email: 'alice@example.com',
    stats: UserStats(cansCount: 7, avgRarity: 3.5),
  );

  setUp(() {
    remote = _MockUserRemoteDataSource();
    repository = UserRepositoryImpl(remote);
  });

  group('getUser', () {
    test('wraps datasource result in Right', () async {
      when(() => remote.getUser(userId)).thenAnswer((_) async => profile);

      final result = await repository.getUser(userId);

      expect(result, const Right<Failure, UserProfile?>(profile));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.getUser(userId),
      ).thenThrow(const ServerException(message: 'boom'));

      final result = await repository.getUser(userId);

      expect(
        result,
        const Left<Failure, UserProfile?>(ServerFailure(message: 'boom')),
      );
    });
  });

  group('watchUser', () {
    test('maps emitted profile into Right', () async {
      when(
        () => remote.watchUser(userId),
      ).thenAnswer((_) => Stream<UserProfile?>.value(profile));

      final values = await repository.watchUser(userId).take(1).toList();

      expect(values, [const Right<Failure, UserProfile?>(profile)]);
    });

    test('maps stream errors to ServerFailure', () async {
      when(
        () => remote.watchUser(userId),
      ).thenAnswer((_) => Stream<UserProfile?>.error(StateError('boom')));

      final emitted = await repository.watchUser(userId).toList();

      expect(emitted.length, 1);
      emitted.first.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('watchUserStats', () {
    test('extracts UserStats from profile stream', () async {
      when(
        () => remote.watchUser(userId),
      ).thenAnswer((_) => Stream<UserProfile?>.value(profile));

      final values = await repository.watchUserStats(userId).take(1).toList();

      expect(values.length, 1);
      values.first.fold(
        (_) => fail('expected Right'),
        (stats) => expect(stats, profile.stats),
      );
    });

    test('emits Right(null) when profile is null', () async {
      when(
        () => remote.watchUser(userId),
      ).thenAnswer((_) => Stream<UserProfile?>.value(null));

      final values = await repository.watchUserStats(userId).take(1).toList();

      expect(values, [const Right<Failure, UserStats?>(null)]);
    });
  });

  group('ensureUserDocument', () {
    test('returns Right(profile) on success', () async {
      when(
        () => remote.ensureUserDocument(
          userId: userId,
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenAnswer((_) async => profile);

      final result = await repository.ensureUserDocument(
        userId: userId,
        email: 'alice@example.com',
        displayName: 'Alice',
      );

      expect(result, const Right<Failure, UserProfile>(profile));
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.ensureUserDocument(
          userId: userId,
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenThrow(const ServerException(message: 'firestore down'));

      final result = await repository.ensureUserDocument(
        userId: userId,
        email: 'a@b.c',
        displayName: 'A',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('updateProfile', () {
    test('forwards parameters to datasource and returns Right(null)', () async {
      when(
        () => remote.updateProfile(
          userId: userId,
          displayName: any(named: 'displayName'),
          bio: any(named: 'bio'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.updateProfile(
        userId: userId,
        displayName: 'New name',
        bio: 'hello',
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => remote.updateProfile(
          userId: userId,
          displayName: 'New name',
          bio: 'hello',
          photoUrl: null,
        ),
      ).called(1);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.updateProfile(
          userId: userId,
          displayName: any(named: 'displayName'),
          bio: any(named: 'bio'),
          photoUrl: any(named: 'photoUrl'),
        ),
      ).thenThrow(const ServerException(message: 'permission denied'));

      final result = await repository.updateProfile(
        userId: userId,
        displayName: 'X',
      );

      expect(result.isLeft(), isTrue);
    });
  });
}
