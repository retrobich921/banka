import 'package:freezed_annotation/freezed_annotation.dart';

import 'drink_type.dart';

part 'drink_rating.freezed.dart';

/// Один критерий оценки: подпись, значение 1–10 и способ применить новое
/// значение. Позволяет редактору не знать, какой профиль он рисует.
class RatingCriterion {
  const RatingCriterion(this.label, this.value, this.apply);

  final String label;
  final int value;
  final DrinkRating Function(int value) apply;
}

/// Составная оценка напитка в стиле «Риса за творчество» (РЗТ).
///
/// Пять критериев 1–10 дают базовую сумму 5..50, а «Вайб» (субъективное
/// «зашло») не прибавляется, а **умножает**. Итоговый балл — 1..90.
///
/// Профилей два, и выбирает их тип напитка:
/// - [DrinkRating.classic] — банки и бутылки без алкоголя: там уместны
///   «баланс сладости» и «дизайн банки»;
/// - [DrinkRating.beer] — пиво: аромат, тело, горечь и питкость.
///
/// Шкала у обоих одна и та же, поэтому баллы сравнимы в общих топах и в
/// карточках напитков. Легаси-документы без `kind` читаются как classic.
@freezed
sealed class DrinkRating with _$DrinkRating {
  const DrinkRating._();

  const factory DrinkRating.classic({
    @Default(5) int taste, // Вкус
    @Default(5) int balance, // Баланс (сладость/кислотность)
    @Default(5) int texture, // Текстура / газация
    @Default(5) int aftertaste, // Послевкусие
    @Default(5) int design, // Дизайн банки
    @Default(5) int vibe, // Вайб (множитель)
  }) = ClassicDrinkRating;

  const factory DrinkRating.beer({
    @Default(5) int taste, // Вкус
    @Default(5) int aroma, // Аромат
    @Default(5) int body, // Тело (плотность)
    @Default(5) int bitterness, // Послевкусие / горечь
    @Default(5) int drinkability, // Питкость
    @Default(5) int vibe, // Вайб (множитель)
  }) = BeerDrinkRating;

  /// Профиль оценки под тип напитка.
  static DrinkRating forType(DrinkType type) => type == DrinkType.beer
      ? const DrinkRating.beer()
      : const DrinkRating.classic();

  /// Пять критериев профиля — в порядке отрисовки.
  List<RatingCriterion> get criteria => switch (this) {
    final ClassicDrinkRating r => [
      RatingCriterion('Вкус', r.taste, (v) => r.copyWith(taste: v)),
      RatingCriterion('Баланс', r.balance, (v) => r.copyWith(balance: v)),
      RatingCriterion(
        'Текстура / газация',
        r.texture,
        (v) => r.copyWith(texture: v),
      ),
      RatingCriterion(
        'Послевкусие',
        r.aftertaste,
        (v) => r.copyWith(aftertaste: v),
      ),
      RatingCriterion('Дизайн банки', r.design, (v) => r.copyWith(design: v)),
    ],
    final BeerDrinkRating r => [
      RatingCriterion('Вкус', r.taste, (v) => r.copyWith(taste: v)),
      RatingCriterion('Аромат', r.aroma, (v) => r.copyWith(aroma: v)),
      RatingCriterion('Тело (плотность)', r.body, (v) => r.copyWith(body: v)),
      RatingCriterion(
        'Послевкусие / горечь',
        r.bitterness,
        (v) => r.copyWith(bitterness: v),
      ),
      RatingCriterion(
        'Питкость',
        r.drinkability,
        (v) => r.copyWith(drinkability: v),
      ),
    ],
  };

  DrinkRating withVibe(int value) => switch (this) {
    final ClassicDrinkRating r => r.copyWith(vibe: value),
    final BeerDrinkRating r => r.copyWith(vibe: value),
  };

  /// Ключ профиля для Firestore.
  String get kind => switch (this) {
    ClassicDrinkRating() => 'classic',
    BeerDrinkRating() => 'beer',
  };

  /// Сумма пяти критериев (5..50 при значениях 1..10).
  int get base => criteria.fold(0, (sum, c) => sum + c.value);

  /// Итоговый балл 1..90: база × (vibe/10) × 1.8. Потолок — 90, пол — 1.
  int get score => (base * (vibe / 10) * 1.8).round().clamp(1, 90);
}
