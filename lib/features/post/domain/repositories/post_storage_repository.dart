import 'dart:io';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';

/// Загружает фотографии поста в Firebase Storage и возвращает готовый
/// `PostPhoto` (с `url` и плейсхолдер-`thumbUrl`, который позже подменит
/// Cloud Function).
///
/// Папка `posts/{postId}/{n}_{filename}` — одна Storage-папка на пост,
/// чтобы при удалении было удобно почистить весь префикс.
abstract interface class PostStorageRepository {
  ResultFuture<PostPhoto> uploadPostImage({
    required String postId,
    required int index,
    required File file,
  });
}
