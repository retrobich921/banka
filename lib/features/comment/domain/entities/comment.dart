import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment.freezed.dart';

/// Комментарий под постом.
///
/// Соответствует документу `posts/{postId}/comments/{commentId}` из
/// `PROJECT_PLAN.md`. Имя автора и аватар денормализованы — рисуем ленту
/// комментариев одним стримом без join-ов в `users`.
@freezed
sealed class Comment with _$Comment {
  const factory Comment({
    required String id,
    required String authorId,
    @Default('') String authorName,
    String? authorPhotoUrl,
    @Default('') String text,
    DateTime? createdAt,
  }) = _Comment;
}
