import '../../../../core/utils/typedefs.dart';
import '../entities/brand.dart';

/// Контракт работы с коллекцией `brands/{brandId}`.
///
/// `searchBrands` — простой `arrayContains`-стиль не используется: брендов
/// мало (десятки-сотни на старте), запрос целиком + фильтрация по prefix
/// дешевле и не требует доп. индексов.
abstract interface class BrandRepository {
  /// Стрим всех брендов, отсортированных по `postsCount desc, name asc`.
  ResultStream<List<Brand>> watchBrands();

  /// Стрим конкретного бренда по id.
  ResultStream<Brand?> watchBrand(String brandId);

  /// Идемпотентное создание (или обновление) бренда: ищем по `slug`,
  /// если есть — возвращаем существующий, иначе создаём. Так несколько
  /// пользователей могут «создать» Monster Energy — получим один
  /// документ.
  ResultFuture<Brand> ensureBrand({
    required String name,
    String? country,
    String? logoUrl,
  });
}
