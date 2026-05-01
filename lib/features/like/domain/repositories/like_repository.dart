import '../../../../core/utils/typedefs.dart';
import '../entities/like.dart';

/// Контракт работы с лайками.
///
/// Лайк хранится в подколлекции `posts/{postId}/likes/{userId}`. В тот же
/// батч клиент пишет «обратный» документ `users/{userId}/likedPosts/{postId}`
/// — чтобы быстро отдавать список лайков пользователя на странице профиля
/// (Sprint 16). `posts/{postId}.likesCount` обновляет Cloud Function
/// `onLikeWritten` (см. `functions/index.js`), поэтому клиент здесь
/// счётчик не трогает.
abstract interface class LikeRepository {
  /// Поставить лайк. Идемпотентно — повторный вызов с теми же id ничего
  /// не сломает.
  ResultFuture<void> likePost({
    required String postId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
  });

  /// Убрать лайк.
  ResultFuture<void> unlikePost({
    required String postId,
    required String userId,
  });

  /// Стрим «лайкал ли я этот пост»: один маленький `get` по
  /// `posts/{postId}/likes/{userId}`.
  ResultStream<bool> watchHasLiked({
    required String postId,
    required String userId,
  });

  /// Стрим списка лайкнувших по убыванию `createdAt` для экрана
  /// «Кто лайкнул».
  ResultStream<List<Like>> watchLikers(String postId);
}
