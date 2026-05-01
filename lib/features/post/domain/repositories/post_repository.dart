import '../../../../core/utils/typedefs.dart';
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
    required List<PostPhoto> photos,
    required DateTime foundDate,
    required int rarity,
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
}
