import 'package:banka/core/error/failures.dart';
import 'package:banka/features/group/domain/entities/group.dart';
import 'package:banka/features/group/domain/usecases/create_group.dart';
import 'package:banka/features/group/domain/usecases/watch_my_groups.dart';
import 'package:banka/features/group/domain/usecases/watch_public_groups.dart';
import 'package:banka/features/group/presentation/bloc/groups_list_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchMyGroups extends Mock implements WatchMyGroups {}

class _MockWatchPublicGroups extends Mock implements WatchPublicGroups {}

class _MockCreateGroup extends Mock implements CreateGroup {}

void main() {
  late _MockWatchMyGroups watchMyGroups;
  late _MockWatchPublicGroups watchPublicGroups;
  late _MockCreateGroup createGroup;

  const userId = 'uid-1';
  final fixtureGroup = Group(
    id: 'grp-new',
    name: 'New',
    ownerId: userId,
    isPublic: true,
    membersUids: const [userId],
    membersCount: 1,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    watchMyGroups = _MockWatchMyGroups();
    watchPublicGroups = _MockWatchPublicGroups();
    createGroup = _MockCreateGroup();

    registerFallbackValue(const WatchPublicGroupsParams());
    registerFallbackValue(const CreateGroupParams(ownerId: '', name: ''));
  });

  GroupsListBloc buildBloc() =>
      GroupsListBloc(watchMyGroups, watchPublicGroups, createGroup);

  group('GroupsListSubscribeRequested', () {
    blocTest<GroupsListBloc, GroupsListState>(
      'emits [loading, ready] when both streams emit lists',
      build: () {
        when(
          () => watchMyGroups(userId),
        ).thenAnswer((_) => Stream.value(Right([fixtureGroup])));
        when(() => watchPublicGroups(any())).thenAnswer(
          (_) => Stream.value(const Right<Failure, List<Group>>([])),
        );
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GroupsListSubscribeRequested(userId)),
      // Two stream emissions land in the bloc as two separate state updates.
      expect: () => [
        // loading from subscribe
        isA<GroupsListState>().having(
          (s) => s.status,
          'status',
          GroupsListStatus.loading,
        ),
        // first stream payload (my)
        isA<GroupsListState>().having((s) => s.myGroups, 'myGroups', [
          fixtureGroup,
        ]),
      ],
    );

    blocTest<GroupsListBloc, GroupsListState>(
      'emits error when my stream fails',
      build: () {
        when(() => watchMyGroups(userId)).thenAnswer(
          (_) => Stream.value(const Left(ServerFailure(message: 'denied'))),
        );
        when(
          () => watchPublicGroups(any()),
        ).thenAnswer((_) => const Stream.empty());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const GroupsListSubscribeRequested(userId)),
      skip: 1, // skip 'loading'
      expect: () => [
        isA<GroupsListState>()
            .having((s) => s.status, 'status', GroupsListStatus.error)
            .having((s) => s.errorMessage, 'errorMessage', 'denied'),
      ],
    );
  });

  group('GroupsListCreateRequested', () {
    blocTest<GroupsListBloc, GroupsListState>(
      'errors when no userId is set yet',
      build: buildBloc,
      act: (bloc) => bloc.add(const GroupsListCreateRequested(name: 'X')),
      expect: () => [
        isA<GroupsListState>()
            .having((s) => s.status, 'status', GroupsListStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              'Профиль ещё не загружен',
            ),
      ],
    );

    blocTest<GroupsListBloc, GroupsListState>(
      'emits [creating, created] and surfaces createdGroupId',
      build: () {
        when(
          () => watchMyGroups(userId),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => watchPublicGroups(any()),
        ).thenAnswer((_) => const Stream.empty());
        when(
          () => createGroup(any()),
        ).thenAnswer((_) async => Right(fixtureGroup));
        return buildBloc();
      },
      act: (bloc) async {
        bloc.add(const GroupsListSubscribeRequested(userId));
        await Future<void>.delayed(const Duration(milliseconds: 20));
        bloc.add(const GroupsListCreateRequested(name: 'New'));
      },
      skip: 1, // skip the loading from subscribe
      expect: () => [
        isA<GroupsListState>().having(
          (s) => s.status,
          'status',
          GroupsListStatus.creating,
        ),
        isA<GroupsListState>()
            .having((s) => s.status, 'status', GroupsListStatus.created)
            .having((s) => s.createdGroupId, 'createdGroupId', 'grp-new'),
      ],
    );
  });

  group('GroupsListCreationAcknowledged', () {
    blocTest<GroupsListBloc, GroupsListState>(
      'clears createdGroupId and resets status to ready',
      build: buildBloc,
      seed: () => const GroupsListState(
        status: GroupsListStatus.created,
        createdGroupId: 'grp-1',
      ),
      act: (bloc) => bloc.add(const GroupsListCreationAcknowledged()),
      expect: () => [const GroupsListState(status: GroupsListStatus.ready)],
    );
  });
}
