import 'package:banka/features/group/data/models/group_dto.dart';
import 'package:banka/features/group/data/models/group_member_dto.dart';
import 'package:banka/features/group/domain/entities/group.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GroupDto.fromMap', () {
    test('parses fully populated group document', () {
      final createdAt = DateTime(2025, 3, 1);
      final updatedAt = DateTime(2025, 4, 15);

      final group = GroupDto.fromMap('grp-1', <String, dynamic>{
        'name': 'Monster Lovers',
        'description': 'Только Monster',
        'ownerId': 'uid-1',
        'coverUrl': 'https://cdn.example.com/cover.png',
        'isPublic': true,
        'membersCount': 42,
        'postsCount': 7,
        'tags': <String>['monster', 'usa'],
        'membersUids': <dynamic>['uid-1', 'uid-2', 99],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(group.id, 'grp-1');
      expect(group.name, 'Monster Lovers');
      expect(group.ownerId, 'uid-1');
      expect(group.isPublic, true);
      expect(group.coverUrl, 'https://cdn.example.com/cover.png');
      expect(group.membersCount, 42);
      expect(group.postsCount, 7);
      expect(group.tags, ['monster', 'usa']);
      // non-strings dropped:
      expect(group.membersUids, ['uid-1', 'uid-2']);
      expect(group.createdAt, createdAt);
      expect(group.updatedAt, updatedAt);
    });

    test('returns sane defaults for missing fields', () {
      final group = GroupDto.fromMap('grp-2', <String, dynamic>{});
      expect(group.id, 'grp-2');
      expect(group.name, '');
      expect(group.ownerId, '');
      expect(group.isPublic, false);
      expect(group.description, '');
      expect(group.coverUrl, isNull);
      expect(group.tags, isEmpty);
      expect(group.membersUids, isEmpty);
      expect(group.membersCount, 0);
      expect(group.postsCount, 0);
    });
  });

  group('GroupDto.toFirestoreMap', () {
    test('emits required fields and skips null coverUrl', () {
      final group = Group(
        id: 'grp-3',
        name: 'Local energetics',
        ownerId: 'uid-9',
        isPublic: false,
        description: 'Region-only finds',
        membersCount: 1,
        membersUids: const ['uid-9'],
        tags: const ['regional'],
        createdAt: DateTime(2025, 5, 1),
        updatedAt: DateTime(2025, 5, 2),
      );

      final map = GroupDto.toFirestoreMap(group);

      expect(map['name'], 'Local energetics');
      expect(map['ownerId'], 'uid-9');
      expect(map['isPublic'], false);
      expect(map.containsKey('coverUrl'), isFalse);
      expect(map['membersCount'], 1);
      expect(map['membersUids'], ['uid-9']);
      expect(map['tags'], ['regional']);
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('round-trip preserves data', () {
      final original = Group(
        id: 'grp-4',
        name: 'Tornado',
        ownerId: 'uid-3',
        isPublic: true,
        description: 'tornado fans',
        coverUrl: 'https://x',
        membersCount: 5,
        postsCount: 12,
        tags: const ['tornado', 'ru'],
        membersUids: const ['uid-3', 'uid-4'],
        createdAt: DateTime(2024, 11, 1),
        updatedAt: DateTime(2024, 12, 1),
      );

      final reparsed = GroupDto.fromMap(
        original.id,
        GroupDto.toFirestoreMap(original),
      );
      expect(reparsed, original);
    });
  });

  group('GroupMemberDto', () {
    test('roleToString round-trip', () {
      final member = GroupMember(
        userId: 'uid-1',
        groupId: 'grp-1',
        role: GroupRole.admin,
        joinedAt: DateTime(2025, 1, 10),
      );
      final map = GroupMemberDto.toFirestoreMap(member);
      expect(map['role'], 'admin');
      expect(map['joinedAt'], isA<Timestamp>());
    });

    test('unknown role falls back to member', () {
      final member = GroupMemberDto.toFirestoreMap(
        const GroupMember(userId: 'uid-1', groupId: 'grp-1'),
      );
      expect(member['role'], 'member');
    });
  });
}
