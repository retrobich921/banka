import 'package:freezed_annotation/freezed_annotation.dart';

part 'like.freezed.dart';

/// Лайк под постом.
///
/// Соответствует документу `posts/{postId}/likes/{userId}` из
/// `PROJECT_PLAN.md`. Имя и аватар автора денормализованы, чтобы
/// рендерить экран «Кто лайкнул» без дополнительных join-ов в `users`.
@freezed
sealed class Like with _$Like {
  const factory Like({
    required String userId,
    @Default('') String userName,
    String? userPhotoUrl,
    DateTime? createdAt,
  }) = _Like;
}
