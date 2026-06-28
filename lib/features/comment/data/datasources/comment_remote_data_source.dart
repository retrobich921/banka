import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/comment.dart';
import '../models/comment_dto.dart';

/// Контракт remote-источника для комментариев. Бросает `ServerException` —
/// repository оборачивает в `Failure`.
abstract interface class CommentRemoteDataSource {
  Future<String> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
  });

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  });

  Stream<List<Comment>> watchComments(String postId);
}

@LazySingleton(as: CommentRemoteDataSource)
final class FirestoreCommentRemoteDataSource
    implements CommentRemoteDataSource {
  FirestoreCommentRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _posts = 'posts';
  static const String _comments = 'comments';

  CollectionReference<Map<String, dynamic>> _commentsRef(String postId) {
    return _firestore.collection(_posts).doc(postId).collection(_comments);
  }

  @override
  Future<String> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Создаём комментарий
      final commentRef = _commentsRef(postId).doc();
      batch.set(
        commentRef,
        CommentDto.toFirestoreMap(
          Comment(
            id: '',
            authorId: authorId,
            authorName: authorName,
            authorPhotoUrl: authorPhotoUrl,
            text: text,
          ),
        ),
      );

      // 2. Инкрементим счётчик комментариев в посте
      batch.update(_firestore.collection(_posts).doc(postId), <String, dynamic>{
        'commentsCount': FieldValue.increment(1),
      });

      await batch.commit();
      return commentRef.id;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message, cause: e);
    } catch (e) {
      throw ServerException(message: e.toString(), cause: e);
    }
  }

  @override
  Future<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Удаляем комментарий
      batch.delete(_commentsRef(postId).doc(commentId));

      // 2. Декрементим счётчик комментариев в посте
      batch.update(_firestore.collection(_posts).doc(postId), <String, dynamic>{
        'commentsCount': FieldValue.increment(-1),
      });

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message, cause: e);
    } catch (e) {
      throw ServerException(message: e.toString(), cause: e);
    }
  }

  @override
  Stream<List<Comment>> watchComments(String postId) {
    return _commentsRef(postId)
        .orderBy(CommentDto.fCreatedAt, descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CommentDto.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }
}
