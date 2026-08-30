import 'package:banka/features/post/domain/entities/drink_rating.dart';
import 'package:banka/features/post/domain/entities/drink_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('профиль по типу напитка', () {
    test('пиво получает пивной профиль', () {
      expect(DrinkRating.forType(DrinkType.beer).kind, 'beer');
    });

    test('остальные типы — классический', () {
      for (final type in DrinkType.values.where((t) => t != DrinkType.beer)) {
        expect(DrinkRating.forType(type).kind, 'classic', reason: type.label);
      }
    });
  });

  group('критерии', () {
    test('в каждом профиле ровно пять критериев', () {
      expect(const DrinkRating.classic().criteria, hasLength(5));
      expect(const DrinkRating.beer().criteria, hasLength(5));
    });

    test('у пива свои подписи', () {
      final labels = const DrinkRating.beer().criteria
          .map((c) => c.label)
          .toList();
      expect(labels, contains('Аромат'));
      expect(labels, contains('Питкость'));
      expect(labels, isNot(contains('Дизайн банки')));
    });

    test('apply возвращает оценку того же профиля с новым значением', () {
      const rating = DrinkRating.beer();
      final updated = rating.criteria.first.apply(9);
      expect(updated.kind, 'beer');
      expect(updated.criteria.first.value, 9);
      // Исходная оценка не мутирует.
      expect(rating.criteria.first.value, 5);
    });
  });

  group('score', () {
    test('шкала общая для обоих профилей', () {
      const classic = DrinkRating.classic(
        taste: 8,
        balance: 8,
        texture: 8,
        aftertaste: 8,
        design: 8,
        vibe: 10,
      );
      const beer = DrinkRating.beer(
        taste: 8,
        aroma: 8,
        body: 8,
        bitterness: 8,
        drinkability: 8,
        vibe: 10,
      );
      expect(classic.base, 40);
      expect(beer.base, 40);
      expect(classic.score, beer.score);
    });

    test('вайб умножает, а не прибавляет', () {
      const low = DrinkRating.beer(vibe: 1);
      const high = DrinkRating.beer(vibe: 10);
      expect(low.score < high.score, isTrue);
      // База 25 × (10/10) × 1.8 = 45.
      expect(high.score, 45);
    });

    test('итог не выходит за 1..90', () {
      const max = DrinkRating.beer(
        taste: 10,
        aroma: 10,
        body: 10,
        bitterness: 10,
        drinkability: 10,
        vibe: 10,
      );
      const min = DrinkRating.classic(
        taste: 1,
        balance: 1,
        texture: 1,
        aftertaste: 1,
        design: 1,
        vibe: 1,
      );
      expect(max.score, 90);
      expect(min.score, greaterThanOrEqualTo(1));
    });
  });

  test('withVibe сохраняет профиль', () {
    expect(const DrinkRating.beer().withVibe(9).kind, 'beer');
    expect(const DrinkRating.classic().withVibe(9).vibe, 9);
  });
}
