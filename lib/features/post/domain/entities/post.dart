import 'package:freezed_annotation/freezed_annotation.dart';

part 'post.freezed.dart';

/// Пост-«банка» — основная сущность каталога.
///
/// Соответствует документу `posts/{postId}` из `PROJECT_PLAN.md`. Автор,
/// группа и бренд денормализованы для отрисовки ленты без джойнов.
/// `searchKeywords` — массив lowercase-токенов из `drinkName` / `brandName`
/// / `tags` (генерируется на клиенте при `create` / `update`), позволяет
/// бесплатный full-text поиск через `where('searchKeywords', arrayContains)`
/// до Sprint 12 — там переедем на Algolia / Typesense, если упрёмся.
@freezed
sealed class Post with _$Post {
  const factory Post({
    required String id,
    required String authorId,
    required String drinkName,
    @Default('') String authorName,
    String? authorPhotoUrl,
    String? groupId,
    String? groupName,
    String? brandId,
    String? brandName,
    @Default(<PostPhoto>[]) List<PostPhoto> photos,
    DateTime? foundDate,
    @Default(1) int rarity,
    @Default('') String description,
    @Default(<String>[]) List<String> tags,
    @Default(0) int likesCount,
    @Default(0) int commentsCount,
    @Default(<String>[]) List<String> searchKeywords,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Post;
}

/// Один кадр карусели поста. `thumbUrl` заполняется Cloud Function
/// `onPostImageUploaded` (см. `functions/index.js`); до её срабатывания
/// `thumbUrl == url`.
@freezed
sealed class PostPhoto with _$PostPhoto {
  const factory PostPhoto({
    required String url,
    required String thumbUrl,
    @Default(0) int width,
    @Default(0) int height,
  }) = _PostPhoto;
}
