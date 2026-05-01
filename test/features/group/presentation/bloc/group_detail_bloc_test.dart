import 'package:banka/core/error/failures.dart';
import 'package:banka/features/group/domain/entities/group.dart';
import 'package:banka/features/group/domain/usecases/delete_group.dart';
import 'package:banka/features/group/domain/usecases/join_group.dart';
import 'package:banka/features/group/domain/usecases/leave_group.dart';
import 'package:banka/features/group/domain/usecases/watch_group.dart';
import 'package:banka/features/group/domain/usecases/watch_group_members.dart';
import 'package:banka/features/group/presentation/bloc/group_detail_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchGroup extends Mock implements WatchGroup {}

class _MockWatchGroupMembers extends Mock implements WatchGroupMembers {}

class _MockJoinGroup extends Mock implements JoinGroup {}

class _MockLeaveGroup extends Mock implements LeaveGroup {}

class _MockDeleteGroup extends Mock implements DeleteGroup {}

void main() {
  late _MockWatchGroup watchGroup;
  late _MockWatchGroupMembers watchGroupMembers;
  late _MockJoinGroup joinGroup;
  late _MockLeaveGroup leaveGroup;
  late _MockDeleteGroup deleteGroup;

  const groupId = 'grp-1';
  const userId = 'uid-1';
  final fixtureGroup = Group(
    id: groupId,
    name: 'Monster',
    ownerId: 'uid-2', // current user is NOT owner
    isPublic: true,
    membersUids: const [userId, 'uid-2'],
    membersCount: 2,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    watchGroup = _MockWatchGroup();
    watchGroupMembers = _MockWatchGroupMembers();
    joinGroup = _MockJoinGroup();
    leaveGroup = _MockLeaveGroup();
    deleteGroup = _MockDeleteGroup();

    registerFallbackValue(const GroupMembershipParams(groupId: '', userId: ''));
  });

  GroupDetailBloc buildBloc() => GroupDetailBloc(
    watchGroup,
    watchGroupMembers,
    joinGroup,
    leaveGroup,
    deleteGroup,
  );

  group('subscribe', () {
    blocTest<GroupDetailBloc, GroupDetailState>(
      'emits ready with group + member list',
      build: () {
        when(
          () => watchGroup(groupId),
        ).thenAnswer((_) => Stream.value(Right(fixtureGroup)));
        when(() => watchGroupMembers(groupId)).thenAnswer(
          (_) => Stream.value(
            const Right<Failure, List<GroupMember>>(<GroupMember>[]),
          ),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const GroupDetailSubscribeRequested(
          groupId: groupId,
          currentUserId: userId,
        ),
      ),
      skip: 1, // skip the initial loading state
      expect: () => [
        isA<GroupDetailState>()
            .having((s) => s.status, 'status', GroupDetailStatus.ready)
            .having((s) => s.group, 'group', fixtureGroup)
            .having((s) => s.isMember, 'isMember', true)
            .having((s) => s.isOwner, 'isOwner', false),
      ],
    );

    blocTest<GroupDetailBloc, GroupDetailState>(
      'emits notFound when watch returns null',
      build: () {
        when(
          () => watchGroup(groupId),
        ).thenAnswer((_) => Stream.value(const Right<Failure, Group?>(null)));
        when(
          () => watchGroupMembers(groupId),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const GroupDetailSubscribeRequested(
          groupId: groupId,
          currentUserId: userId,
        ),
      ),
      skip: 1,
      expect: () => [
        isA<GroupDetailState>().having(
          (s) => s.status,
          'status',
          GroupDetailStatus.notFound,
        ),
      ],
    );
  });

  group('mutations', () {
    blocTest<GroupDetailBloc, GroupDetailState>(
      'joinGroup transitions [mutating, ready]',
      build: () {
        when(
          () => watchGroup(groupId),
        ).thenAnswer((_) => Stream.value(Right(fixtureGroup)));
        when(
          () => watchGroupMembers(groupId),
        ).thenAnswer((_) => const Stream.empty());
        when(() => joinGroup(any())).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const GroupDetailSubscribeRequested(
            groupId: groupId,
            currentUserId: userId,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const GroupDetailJoinRequested());
      },
      // After ready (ignore), expect mutating then ready again.
      skip: 2, // loading + initial ready
      expect: () => [
        isA<GroupDetailState>().having(
          (s) => s.status,
          'status',
          GroupDetailStatus.mutating,
        ),
        isA<GroupDetailState>().having(
          (s) => s.status,
          'status',
          GroupDetailStatus.ready,
        ),
      ],
    );

    blocTest<GroupDetailBloc, GroupDetailState>(
      'deleteGroup emits deleted on success',
      build: () {
        when(
          () => watchGroup(groupId),
        ).thenAnswer((_) => Stream.value(Right(fixtureGroup)));
        when(
          () => watchGroupMembers(groupId),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => deleteGroup(groupId),
        ).thenAnswer((_) async => const Right(null));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const GroupDetailSubscribeRequested(
            groupId: groupId,
            currentUserId: userId,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const GroupDetailDeleteRequested());
      },
      skip: 2,
      expect: () => [
        isA<GroupDetailState>().having(
          (s) => s.status,
          'status',
          GroupDetailStatus.mutating,
        ),
        isA<GroupDetailState>().having(
          (s) => s.status,
          'status',
          GroupDetailStatus.deleted,
        ),
      ],
    );

    blocTest<GroupDetailBloc, GroupDetailState>(
      'leaveGroup surfaces error from usecase',
      build: () {
        when(
          () => watchGroup(groupId),
        ).thenAnswer((_) => Stream.value(Right(fixtureGroup)));
        when(
          () => watchGroupMembers(groupId),
        ).thenAnswer((_) => const Stream.empty());
        when(() => leaveGroup(any())).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'permission denied')),
        );
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(
          const GroupDetailSubscribeRequested(
            groupId: groupId,
            currentUserId: userId,
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const GroupDetailLeaveRequested());
      },
      skip: 2,
      expect: () => [
        isA<GroupDetailState>().having(
          (s) => s.status,
          'status',
          GroupDetailStatus.mutating,
        ),
        isA<GroupDetailState>()
            .having((s) => s.status, 'status', GroupDetailStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'permission denied'),
      ],
    );
  });
}
