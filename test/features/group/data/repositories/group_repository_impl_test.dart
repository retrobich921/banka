import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/group/data/datasources/group_remote_data_source.dart';
import 'package:banka/features/group/data/repositories/group_repository_impl.dart';
import 'package:banka/features/group/domain/entities/group.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements GroupRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late GroupRepositoryImpl repository;

  const groupId = 'grp-1';
  const userId = 'uid-1';
  final group = Group(
    id: groupId,
    name: 'Monster',
    ownerId: userId,
    isPublic: true,
    membersUids: const [userId],
    membersCount: 1,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    remote = _MockRemote();
    repository = GroupRepositoryImpl(remote);
  });

  group_('createGroup wraps remote', () {
    test('returns Right(group) on success', () async {
      when(
        () => remote.createGroup(
          ownerId: any(named: 'ownerId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          tags: any(named: 'tags'),
          coverUrl: any(named: 'coverUrl'),
        ),
      ).thenAnswer((_) async => group);

      final result = await repository.createGroup(
        ownerId: userId,
        name: 'Monster',
      );

      expect(result, Right<Failure, Group>(group));
    });

    test('maps ServerException to Left(ServerFailure)', () async {
      when(
        () => remote.createGroup(
          ownerId: any(named: 'ownerId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          tags: any(named: 'tags'),
          coverUrl: any(named: 'coverUrl'),
        ),
      ).thenThrow(const ServerException(message: 'denied'));

      final result = await repository.createGroup(
        ownerId: userId,
        name: 'Monster',
      );

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group_('streams', () {
    test('watchGroup wraps each value in Right', () async {
      when(
        () => remote.watchGroup(groupId),
      ).thenAnswer((_) => Stream.value(group));

      final emitted = await repository.watchGroup(groupId).take(1).toList();

      expect(emitted, [Right<Failure, Group?>(group)]);
    });

    test('watchGroup converts stream errors to Left(ServerFailure)', () async {
      when(
        () => remote.watchGroup(groupId),
      ).thenAnswer((_) => Stream.error(StateError('boom')));

      final emitted = await repository.watchGroup(groupId).toList();

      expect(emitted.length, 1);
      emitted.first.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('watchMyGroups wraps list in Right', () async {
      when(
        () => remote.watchMyGroups(userId),
      ).thenAnswer((_) => Stream.value([group]));

      final emitted = await repository.watchMyGroups(userId).take(1).toList();

      expect(emitted.length, 1);
      emitted.first.fold(
        (_) => fail('expected Right'),
        (groups) => expect(groups, [group]),
      );
    });
  });

  group_('membership commands', () {
    test('joinGroup forwards parameters', () async {
      when(
        () => remote.joinGroup(groupId: groupId, userId: userId),
      ).thenAnswer((_) async {});

      final result = await repository.joinGroup(
        groupId: groupId,
        userId: userId,
      );

      expect(result, const Right<Failure, void>(null));
      verify(
        () => remote.joinGroup(groupId: groupId, userId: userId),
      ).called(1);
    });

    test('leaveGroup maps exceptions', () async {
      when(
        () => remote.leaveGroup(groupId: groupId, userId: userId),
      ).thenThrow(const ServerException(message: 'nope'));

      final result = await repository.leaveGroup(
        groupId: groupId,
        userId: userId,
      );

      expect(result.isLeft(), isTrue);
    });

    test('getMembership returns Right(null) when not a member', () async {
      when(
        () => remote.getMembership(groupId: groupId, userId: userId),
      ).thenAnswer((_) async => null);

      final result = await repository.getMembership(
        groupId: groupId,
        userId: userId,
      );

      expect(result, const Right<Failure, GroupMember?>(null));
    });
  });

  group_('updateGroup / deleteGroup', () {
    test('updateGroup returns Right(null) on success', () async {
      when(
        () => remote.updateGroup(
          groupId: any(named: 'groupId'),
          name: any(named: 'name'),
          description: any(named: 'description'),
          isPublic: any(named: 'isPublic'),
          coverUrl: any(named: 'coverUrl'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async {});

      final result = await repository.updateGroup(
        groupId: groupId,
        name: 'New name',
      );

      expect(result, const Right<Failure, void>(null));
    });

    test('deleteGroup wraps remote', () async {
      when(() => remote.deleteGroup(groupId)).thenAnswer((_) async {});
      final result = await repository.deleteGroup(groupId);
      expect(result, const Right<Failure, void>(null));
    });
  });
}

// Helper alias to avoid clashes with flutter_test's `group`.
void group_(String description, dynamic Function() body) =>
    group(description, body);
