import 'package:banka/features/post/data/models/post_dto.dart';
import 'package:banka/features/post/domain/entities/drink_rating.dart';
import 'package:banka/features/post/domain/entities/drink_spec.dart';
import 'package:banka/features/post/domain/entities/drink_type.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('оценка: профиль в Firestore', () {
    test('легаси-документ без kind читается как классический', () {
      final post = PostDto.fromMap('p-1', <String, dynamic>{
        'authorId': 'uid',
        'drinkName': 'Monster',
        'rating': <String, dynamic>{
          'taste': 8,
          'balance': 7,
          'texture': 6,
          'aftertaste': 5,
          'design': 9,
          'vibe': 10,
        },
      });

      expect(post.rating!.kind, 'classic');
      expect(post.rating!.base, 35);
    });

    test('пивная оценка сохраняется и читается со своими критериями', () {
      const rating = DrinkRating.beer(
        taste: 9,
        aroma: 8,
        body: 7,
        bitterness: 6,
        drinkability: 10,
        vibe: 9,
      );
      final map = PostDto.toFirestoreMap(
        const Post(
          id: 'p-2',
          authorId: 'uid',
          drinkName: 'Балтика 7',
          drinkType: DrinkType.beer,
          rating: rating,
        ),
      );

      final stored = map['rating'] as Map<String, dynamic>;
      expect(stored['kind'], 'beer');
      expect(stored['aroma'], 8);
      expect(stored['drinkability'], 10);
      // Балл дублируется отдельным полем для сортировок в топах.
      expect(map['ratingScore'], rating.score);

      final restored = PostDto.fromMap('p-2', map);
      expect(restored.rating, rating);
    });
  });

  group('характеристики напитка', () {
    test('spec пишется и читается целиком', () {
      const spec = DrinkSpec(
        abv: 5.4,
        style: BeerStyle.ipa,
        container: DrinkContainer.can,
        volumeMl: 450,
        ibu: 45,
      );
      final map = PostDto.toFirestoreMap(
        const Post(
          id: 'p-3',
          authorId: 'uid',
          drinkName: 'IPA',
          drinkType: DrinkType.beer,
          spec: spec,
        ),
      );

      expect(map['spec'], <String, dynamic>{
        'abv': 5.4,
        'style': 'ipa',
        'container': 'can',
        'volumeMl': 450,
        'ibu': 45,
      });
      expect(PostDto.fromMap('p-3', map).spec, spec);
    });

    test('пустой spec в документ не попадает', () {
      final map = PostDto.toFirestoreMap(
        const Post(
          id: 'p-4',
          authorId: 'uid',
          drinkName: 'Кола',
          spec: DrinkSpec(),
        ),
      );
      expect(map.containsKey('spec'), isFalse);
    });

    test('документ без spec читается как null', () {
      final post = PostDto.fromMap('p-5', <String, dynamic>{
        'authorId': 'uid',
        'drinkName': 'Кола',
      });
      expect(post.spec, isNull);
    });

    test('неизвестный стиль превращается в «Другое», а не роняет парсинг', () {
      final post = PostDto.fromMap('p-6', <String, dynamic>{
        'authorId': 'uid',
        'drinkName': 'Пиво',
        'spec': <String, dynamic>{'style': 'gose-imperial-2077'},
      });
      expect(post.spec!.style, BeerStyle.other);
    });
  });

  group('DrinkSpec.shortLabel', () {
    test('крепость и стиль через точку', () {
      const spec = DrinkSpec(abv: 5.4, style: BeerStyle.ipa);
      expect(spec.shortLabel, '5,4% · IPA');
    });

    test('целая крепость без дробной части', () {
      const spec = DrinkSpec(abv: 5);
      expect(spec.shortLabel, '5%');
    });
  });
}
