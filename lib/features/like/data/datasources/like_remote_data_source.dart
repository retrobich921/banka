import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/like.dart';
import '../models/like_dto.dart';

/// Контракт remote-источника для лайков. Бросает `ServerException` —
/// repository оборачивает в `Failure`.
abstract interface class LikeRemoteDataSource {
  Future<void> likePost({
    required String postId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
  });

  Future<void> unlikePost({required String postId, required String userId});

  Stream<bool> watchHasLiked({required String postId, required String userId});

  Stream<List<Like>> watchLikers(String postId);
}

@LazySingleton(as: LikeRemoteDataSource)
final class FirestoreLikeRemoteDataSource implements LikeRemoteDataSource {
  FirestoreLikeRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _posts = 'posts';
  static const String _likes = 'likes';
  static const String _users = 'users';
  static const String _likedPosts = 'likedPosts';

  @override
  Future<void> likePost({
    required String postId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
  }) async {
    try {
      final batch = _firestore.batch();

      // 1. Лайк в подколлекции поста — Cloud Function `onLikeWritten`
      //    после этого инкрементит `posts/{postId}.likesCount`.
      batch.set(
        _firestore
            .collection(_posts)
            .doc(postId)
            .collection(_likes)
            .doc(userId),
        LikeDto.toFirestoreMap(
          Like(userId: userId, userName: userName, userPhotoUrl: userPhotoUrl),
        ),
      );

      // 2. «Обратный» документ в `users/{uid}/likedPosts/{postId}` — нужен,
      //    чтобы быстро отдавать «мои лайки» на профиле (Sprint 16).
      batch.set(
        _firestore
            .collection(_users)
            .doc(userId)
            .collection(_likedPosts)
            .doc(postId),
        <String, dynamic>{'createdAt': FieldValue.serverTimestamp()},
      );

      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message, cause: e);
    } catch (e) {
      throw ServerException(message: e.toString(), cause: e);
    }
  }

  @override
  Future<void> unlikePost({
    required String postId,
    required String userId,
  }) async {
    try {
      final batch = _firestore.batch();
      batch.delete(
        _firestore
            .collection(_posts)
            .doc(postId)
            .collection(_likes)
            .doc(userId),
      );
      batch.delete(
        _firestore
            .collection(_users)
            .doc(userId)
            .collection(_likedPosts)
            .doc(postId),
      );
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message, cause: e);
    } catch (e) {
      throw ServerException(message: e.toString(), cause: e);
    }
  }

  @override
  Stream<bool> watchHasLiked({required String postId, required String userId}) {
    return _firestore
        .collection(_posts)
        .doc(postId)
        .collection(_likes)
        .doc(userId)
        .snapshots()
        .map((s) => s.exists);
  }

  @override
  Stream<List<Like>> watchLikers(String postId) {
    return _firestore
        .collection(_posts)
        .doc(postId)
        .collection(_likes)
        .orderBy(LikeDto.fCreatedAt, descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => LikeDto.fromMap(d.id, d.data()))
              .toList(growable: false),
        );
  }
}
