import 'package:banka/features/post/data/models/post_dto.dart';
import 'package:banka/features/post/data/models/post_photo_dto.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PostDto.fromMap', () {
    test('parses fully populated post document', () {
      final createdAt = DateTime(2025, 3, 1);
      final updatedAt = DateTime(2025, 4, 15);
      final foundDate = DateTime(2025, 2, 1);

      final post = PostDto.fromMap('p-1', <String, dynamic>{
        'authorId': 'uid-1',
        'authorName': 'Albert',
        'authorPhotoUrl': 'https://cdn.example.com/u.png',
        'groupId': 'grp-1',
        'groupName': 'Monster Lovers',
        'brandId': 'br-1',
        'brandName': 'Monster',
        'drinkName': 'Monster Energy Original',
        'photos': <Map<String, dynamic>>[
          <String, dynamic>{
            'url': 'https://cdn/1.jpg',
            'thumbUrl': 'https://cdn/1_thumb.jpg',
            'width': 1600,
            'height': 1200,
          },
        ],
        'foundDate': Timestamp.fromDate(foundDate),
        'rarity': 7,
        'description': 'Found in 7-Eleven',
        'tags': <String>['monster', 'usa'],
        'likesCount': 5,
        'commentsCount': 2,
        'searchKeywords': <String>['monster', 'energy'],
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      });

      expect(post.id, 'p-1');
      expect(post.authorId, 'uid-1');
      expect(post.authorName, 'Albert');
      expect(post.groupId, 'grp-1');
      expect(post.brandName, 'Monster');
      expect(post.drinkName, 'Monster Energy Original');
      expect(post.photos, hasLength(1));
      expect(post.photos.first.url, 'https://cdn/1.jpg');
      expect(post.photos.first.thumbUrl, 'https://cdn/1_thumb.jpg');
      expect(post.photos.first.width, 1600);
      expect(post.foundDate, foundDate);
      expect(post.rarity, 7);
      expect(post.likesCount, 5);
      expect(post.commentsCount, 2);
      expect(post.tags, ['monster', 'usa']);
      expect(post.createdAt, createdAt);
      expect(post.updatedAt, updatedAt);
    });

    test('returns sane defaults for missing fields', () {
      final post = PostDto.fromMap('p-2', <String, dynamic>{});
      expect(post.authorId, '');
      expect(post.drinkName, '');
      expect(post.photos, isEmpty);
      expect(post.rarity, 1);
      expect(post.likesCount, 0);
      expect(post.commentsCount, 0);
      expect(post.tags, isEmpty);
      expect(post.searchKeywords, isEmpty);
      expect(post.foundDate, isNull);
    });
  });

  group('PostDto.toFirestoreMap', () {
    test('omits null optional fields and serialises photos', () {
      final post = Post(
        id: 'p-3',
        authorId: 'uid-1',
        authorName: 'A',
        drinkName: 'Burn Original',
        photos: const [
          PostPhoto(
            url: 'https://cdn/burn.jpg',
            thumbUrl: 'https://cdn/burn_thumb.jpg',
            width: 1200,
            height: 1600,
          ),
        ],
        foundDate: DateTime(2025, 1, 5),
        rarity: 3,
        createdAt: DateTime(2025, 1, 5),
      );

      final map = PostDto.toFirestoreMap(post);

      expect(map['authorId'], 'uid-1');
      expect(map['drinkName'], 'Burn Original');
      expect(map.containsKey('groupId'), isFalse);
      expect(map.containsKey('brandId'), isFalse);
      expect(map['rarity'], 3);
      expect(map['photos'], isA<List<dynamic>>());
      expect(map['createdAt'], isA<Timestamp>());

      final photoMap = (map['photos'] as List).first as Map<String, dynamic>;
      expect(photoMap['url'], 'https://cdn/burn.jpg');
      expect(photoMap['thumbUrl'], 'https://cdn/burn_thumb.jpg');
    });

    test('round-trip preserves data', () {
      final original = Post(
        id: 'p-4',
        authorId: 'uid-2',
        authorName: 'B',
        drinkName: 'Adrenaline Rush',
        groupId: 'grp-2',
        brandName: 'Adrenaline',
        photos: const [
          PostPhoto(
            url: 'https://cdn/a.jpg',
            thumbUrl: 'https://cdn/a_thumb.jpg',
            width: 800,
            height: 600,
          ),
        ],
        foundDate: DateTime(2025, 6, 1),
        rarity: 5,
        description: 'so cool',
        tags: const ['ru'],
        likesCount: 3,
        commentsCount: 1,
        searchKeywords: const ['adrenaline', 'rush', 'ru'],
        createdAt: DateTime(2025, 6, 1),
        updatedAt: DateTime(2025, 6, 2),
      );

      final reparsed = PostDto.fromMap(
        original.id,
        PostDto.toFirestoreMap(original),
      );
      expect(reparsed, original);
    });
  });

  group('PostDto.buildSearchKeywords', () {
    test('lowercases, deduplicates, drops short tokens', () {
      final tokens = PostDto.buildSearchKeywords(
        drinkName: 'Monster Energy Original',
        brandName: 'Monster',
        tags: const ['USA', 'limited', 'A'],
      );
      // 'A' (1 char) dropped; 'monster' deduped.
      expect(
        tokens,
        containsAll(['monster', 'energy', 'original', 'usa', 'limited']),
      );
      expect(tokens.where((t) => t == 'monster').length, 1);
    });

    test('handles empty brand and tags', () {
      final tokens = PostDto.buildSearchKeywords(drinkName: 'Burn');
      expect(tokens, contains('burn'));
    });
  });

  group('PostPhotoDto', () {
    test('falls back thumbUrl to url when missing', () {
      final photo = PostPhotoDto.fromMap(<String, dynamic>{
        'url': 'https://cdn/x.jpg',
      });
      expect(photo.thumbUrl, 'https://cdn/x.jpg');
    });
  });
}
