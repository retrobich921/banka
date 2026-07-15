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

/// Детерминированный ключ карточки напитка: **бренд + вкус**.
///
/// Название поста — свободное творчество автора («я хз что писать») и для
/// идентификации напитка не годится. Напиток определяют структурные поля:
/// бренд и вкус из пикеров. Пост без выбранного бренда или вкуса в карточку
/// не агрегируется (возвращается null).
String? drinkKeyOf({String? brandId, String? flavorId}) {
  if (brandId == null || brandId.isEmpty) return null;
  if (flavorId == null || flavorId.isEmpty) return null;
  return '$brandId--$flavorId';
}

/// Отображаемое имя карточки: «Бренд Вкус».
String drinkDisplayName({String? brandName, String? flavorName}) => [
  if (brandName != null && brandName.isNotEmpty) brandName,
  if (flavorName != null && flavorName.isNotEmpty) flavorName,
].join(' ');
