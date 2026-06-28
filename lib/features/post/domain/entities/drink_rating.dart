import 'package:freezed_annotation/freezed_annotation.dart';

part 'drink_rating.freezed.dart';

/// Составная оценка напитка в стиле «Риса за творчество» (РЗТ).
///
/// Пять критериев 1–10 (включая дизайн банки) дают базовую сумму 5..50,
/// а «Вайб» (субъективное «зашло») — не прибавляется, а **умножает**.
/// Итоговый балл — 1..90.
@freezed
sealed class DrinkRating with _$DrinkRating {
  const DrinkRating._();

  const factory DrinkRating({
    @Default(5) int taste, // Вкус
    @Default(5) int balance, // Баланс (сладость/кислотность)
    @Default(5) int texture, // Текстура / газация
    @Default(5) int aftertaste, // Послевкусие
    @Default(5) int design, // Дизайн банки
    @Default(5) int vibe, // Вайб (множитель)
  }) = _DrinkRating;

  /// Сумма пяти критериев (5..50 при значениях 1..10).
  int get base => taste + balance + texture + aftertaste + design;

  /// Итоговый балл 1..90: база × (vibe/10) × 1.8. Потолок — 90, пол — 1.
  int get score => (base * (vibe / 10) * 1.8).round().clamp(1, 90);
}
