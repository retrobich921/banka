import 'package:freezed_annotation/freezed_annotation.dart';

part 'drink.freezed.dart';

/// Карточка напитка (`drinks/{drinkId}`) — агрегат по всем постам об одном
/// напитке (РЗТ-стиль: релиз ← рецензии). Денорм-счётчики инкрементятся
/// клиентом в том же батче, что и создание/удаление поста (Spark-план,
/// Cloud Functions недоступны).
@freezed
sealed class Drink with _$Drink {
  const Drink._();

  const factory Drink({
    required String id,
    required String name,
    String? brandId,
    String? brandName,

    /// Превью последнего поста — обложка карточки.
    String? thumbUrl,
    @Default(0) int postsCount,

    /// Сумма и число оценок (только посты с рейтингом).
    @Default(0.0) double ratingSum,
    @Default(0) int ratingCount,

    /// Сумма и число указанных цен (для средней).
    @Default(0.0) double pricesSum,
    @Default(0) int pricesCount,

    /// Магазин → сколько раз там покупали (для «80% в Пятёрочке»).
    @Default(<String, int>{}) Map<String, int> stores,
    DateTime? updatedAt,
  }) = _Drink;

  /// Средняя оценка сообщества (null — никто не оценивал).
  double? get ratingAvg => ratingCount == 0 ? null : ratingSum / ratingCount;

  /// Средняя цена (null — цены не указывали).
  double? get priceAvg => pricesCount == 0 ? null : pricesSum / pricesCount;
}

/// Детерминированный ключ карточки напитка: слаг названия + бренд.
/// Один и тот же напиток из разных постов попадает в одну карточку.
String drinkKeyOf(String drinkName, String? brandId) {
  var slug = drinkName
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-zа-яё0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) slug = 'drink';
  if (slug.length > 80) slug = slug.substring(0, 80);
  return (brandId == null || brandId.isEmpty) ? slug : '$slug--$brandId';
}
