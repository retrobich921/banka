import 'package:banka/features/user/data/models/user_profile_dto.dart';
import 'package:banka/features/user/domain/entities/user_profile.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserProfileDto.fromMap', () {
    test('parses a fully populated map', () {
      final createdAt = DateTime(2025, 1, 1);
      final updatedAt = DateTime(2025, 6, 15);

      final map = <String, dynamic>{
        'displayName': 'Alice',
        'email': 'alice@example.com',
        'photoUrl': 'https://cdn.example.com/avatar.png',
        'bio': 'Энергетики — это жизнь.',
        'stats': <String, dynamic>{
          'cansCount': 12,
          'likesReceived': 99,
          'groupsCount': 3,
          'avgRarity': 4.5,
          'topBrandId': 'brand-monster',
        },
        'fcmTokens': <String>['token-1', 'token-2'],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

      final profile = UserProfileDto.fromMap('uid-1', map);

      expect(profile.id, 'uid-1');
      expect(profile.displayName, 'Alice');
      expect(profile.email, 'alice@example.com');
      expect(profile.photoUrl, 'https://cdn.example.com/avatar.png');
      expect(profile.bio, 'Энергетики — это жизнь.');
      expect(profile.fcmTokens, ['token-1', 'token-2']);
      expect(profile.createdAt, createdAt);
      expect(profile.updatedAt, updatedAt);
      expect(profile.stats.cansCount, 12);
      expect(profile.stats.likesReceived, 99);
      expect(profile.stats.groupsCount, 3);
      expect(profile.stats.avgRarity, 4.5);
      expect(profile.stats.topBrandId, 'brand-monster');
    });

    test('returns sane defaults for empty stats / missing fields', () {
      final profile = UserProfileDto.fromMap('uid-2', <String, dynamic>{});

      expect(profile.id, 'uid-2');
      expect(profile.displayName, '');
      expect(profile.email, '');
      expect(profile.photoUrl, isNull);
      expect(profile.bio, isNull);
      expect(profile.fcmTokens, isEmpty);
      expect(profile.createdAt, isNull);
      expect(profile.stats, const UserStats());
    });

    test('drops non-string entries from fcmTokens', () {
      final profile = UserProfileDto.fromMap('uid-3', <String, dynamic>{
        'fcmTokens': <dynamic>['ok-token', 42, null, 'another'],
      });

      expect(profile.fcmTokens, ['ok-token', 'another']);
    });
  });

  group('UserProfileDto.toFirestoreMap', () {
    test('emits all populated fields and skips null bio/photoUrl', () {
      final profile = UserProfile(
        id: 'uid-4',
        displayName: 'Bob',
        email: 'bob@example.com',
        stats: const UserStats(cansCount: 5, avgRarity: 3.2),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 2),
      );

      final map = UserProfileDto.toFirestoreMap(profile);

      expect(map['displayName'], 'Bob');
      expect(map['email'], 'bob@example.com');
      expect(map.containsKey('photoUrl'), isFalse);
      expect(map.containsKey('bio'), isFalse);
      expect(map['fcmTokens'], <String>[]);
      expect(map['stats'], <String, dynamic>{
        'cansCount': 5,
        'likesReceived': 0,
        'groupsCount': 0,
        'avgRarity': 3.2,
      });
      expect(map['createdAt'], isA<Timestamp>());
      expect(map['updatedAt'], isA<Timestamp>());
    });

    test('round-trip preserves data', () {
      final original = UserProfile(
        id: 'uid-5',
        displayName: 'Carol',
        email: 'c@e.com',
        photoUrl: 'p',
        bio: 'b',
        stats: const UserStats(
          cansCount: 1,
          likesReceived: 2,
          groupsCount: 3,
          avgRarity: 4.0,
          topBrandId: 'brand-x',
        ),
        fcmTokens: const ['t'],
        createdAt: DateTime(2024, 12, 1),
        updatedAt: DateTime(2024, 12, 2),
      );

      final map = UserProfileDto.toFirestoreMap(original);
      final reparsed = UserProfileDto.fromMap(original.id, map);

      expect(reparsed, original);
    });
  });
}
