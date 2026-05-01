import '../../../../core/utils/typedefs.dart';
import '../entities/comment.dart';

/// Контракт работы с комментариями.
///
/// Комментарии хранятся в подколлекции `posts/{postId}/comments/{commentId}`.
/// Денорм-счётчик `posts/{postId}.commentsCount` обновляет Cloud Function
/// `onCommentCreated/Deleted` (см. `functions/index.js`) — клиент его не
/// трогает.
abstract interface class CommentRepository {
  /// Создать комментарий. Возвращает id созданного документа.
  ResultFuture<String> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
  });

  /// Удалить комментарий. Доступно только автору (Firestore Rules).
  ResultFuture<void> deleteComment({
    required String postId,
    required String commentId,
  });

  /// Real-time стрим комментариев поста по убыванию `createdAt`.
  ResultStream<List<Comment>> watchComments(String postId);
}
