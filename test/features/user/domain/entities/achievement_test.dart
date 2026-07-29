import 'package:banka/features/user/domain/entities/achievement.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('earnedAchievements', () {
    test('пустой список, пока нет ни одной банки', () {
      expect(earnedAchievements(0), isEmpty);
    });

    test('возвращает полученные от «дорогих» к простым', () {
      final earned = earnedAchievements(120);
      expect(earned.first.id, 'cans100');
      expect(earned.map((a) => a.id), contains('cans1'));
      expect(earned.map((a) => a.id), isNot(contains('cans150')));
    });
  });

  group('nextAchievement', () {
    test('ближайшая невыполненная цель', () {
      expect(nextAchievement(0)?.id, 'cans1');
      expect(nextAchievement(99)?.id, 'cans100');
      // Цель взята — показываем уже следующую.
      expect(nextAchievement(100)?.id, 'cans150');
    });

    test('null, когда собраны все', () {
      expect(nextAchievement(10000), isNull);
    });
  });

  group('nextAchievementProgress', () {
    test('считается от порога предыдущей ачивки', () {
      // 125 из отрезка 100..150 — ровно половина.
      expect(nextAchievementProgress(125), closeTo(0.5, 0.001));
    });

    test('всё собрано — 1', () {
      expect(nextAchievementProgress(10000), 1);
    });
  });

  group('visibleAchievements', () {
    test('без выбора показывает последние полученные', () {
      final shown = visibleAchievements(cansCount: 120, pinnedIds: const []);
      expect(shown.length, 3);
      expect(shown.first.id, 'cans100');
    });

    test('уважает выбор пользователя', () {
      final shown = visibleAchievements(
        cansCount: 120,
        pinnedIds: const ['cans1', 'cans50'],
      );
      expect(shown.map((a) => a.id), ['cans50', 'cans1']);
    });

    test('игнорирует выбранные, но ещё не полученные', () {
      final shown = visibleAchievements(
        cansCount: 5,
        pinnedIds: const ['cans300'],
      );
      expect(shown.map((a) => a.id), ['cans1']);
    });
  });
}
