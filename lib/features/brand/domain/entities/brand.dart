import 'package:freezed_annotation/freezed_annotation.dart';

part 'brand.freezed.dart';

/// Бренд энергетика (Red Bull, Monster, Adrenaline, Burn, Tornado, …).
///
/// Соответствует документу `brands/{brandId}` из `PROJECT_PLAN.md`.
/// `slug` — `name.toLowerCase()` без пробелов / диакритик, используется
/// для уникальности (ищем перед созданием) и стабильных ссылок. Поле
/// `postsCount` — денормализованный счётчик, обновляемый Cloud Function
/// `onPostWriteUpdateBrandStats` (см. `functions/index.js`); клиент
/// никогда не пишет в него напрямую.
@freezed
sealed class Brand with _$Brand {
  const factory Brand({
    required String id,
    required String name,
    required String slug,
    String? logoUrl,
    String? country,
    @Default(0) int postsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Brand;
}
