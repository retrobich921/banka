import '../../../../core/utils/typedefs.dart';
import '../entities/drink_type.dart';
import '../entities/post.dart';

/// Контракт работы с коллекцией `posts/{postId}`.
///
/// Все методы — `ResultFuture` или `ResultStream` (см. `core/utils/typedefs.dart`),
/// исключения никогда не пробрасываются в presentation: на уровне
/// репозитория ловим `ServerException` и оборачиваем в `Failure`.
abstract interface class PostRepository {
  ResultFuture<Post> createPost({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String drinkName,
    String? groupId,
    String? groupName,
    String? brandId,
    String? brandName,
    String? flavorId,
    String? flavorName,
    required List<PostPhoto> photos,
    required DateTime foundDate,
    required int rarity,
    int tasteRating = 0,
    DrinkType drinkType = DrinkType.energy,
    String description = '',
    List<String> tags = const <String>[],
  });

  ResultFuture<Post?> getPost(String postId);

  ResultStream<Post?> watchPost(String postId);

  /// Глобальная лента «Все», `orderBy(createdAt desc)`.
  ResultStream<List<Post>> watchFeed({int limit = 20, String? startAfterId});

  /// Лента группы, `where(groupId) + orderBy(createdAt desc)`.
  ResultStream<List<Post>> watchGroupFeed({
    required String groupId,
    int limit = 20,
    String? startAfterId,
  });

  /// Все посты пользователя, `where(authorId) + orderBy(createdAt desc)`.
  ResultStream<List<Post>> watchAuthorFeed({
    required String authorId,
    int limit = 20,
    String? startAfterId,
  });

  /// Sprint 13 — лента бренда. `where(brandId) + orderBy(rarity desc)` —
  /// карточки идут от самых редких к обычным, чтобы экран бренда
  /// смотрелся как витрина «лучших экспонатов».
  ResultStream<List<Post>> watchBrandFeed({
    required String brandId,
    int limit = 20,
    String? startAfterId,
  });

  /// Разовая загрузка следующей страницы ленты (для подгрузки при скролле).
  /// Скоуп определяется единственным заданным id; иначе — глобальная лента.
  ResultFuture<List<Post>> getFeedPage({
    String? groupId,
    String? brandId,
    String? authorId,
    String? startAfterId,
    int limit = 20,
  });

  ResultFuture<void> updatePost({
    required String postId,
    String? drinkName,
    String? brandId,
    String? brandName,
    DateTime? foundDate,
    int? rarity,
    String? description,
    List<String>? tags,
  });

  ResultFuture<void> deletePost(String postId);

  /// Sprint 12 — поиск постов: `arrayContains`-запрос по `searchKeywords`
  /// с опциональными фильтрами (rarity range / brandId / groupId).
  /// Возвращает «снэпшот» (Future, без real-time) — поиск интерактивен,
  /// каждый ввод порождает новый запрос.
  ResultFuture<List<Post>> searchPosts({
    String? query,
    int? rarityMin,
    int? rarityMax,
    String? brandId,
    String? groupId,
    int limit = 50,
  });
}
