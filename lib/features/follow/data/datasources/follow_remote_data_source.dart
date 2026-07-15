import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';

/// Контракт remote-источника подписок. Бросает `ServerException` —
/// repository оборачивает в `Failure`.
abstract interface class FollowRemoteDataSource {
  Future<void> follow({
    required String followerId,
    required String targetUserId,
  });

  Future<void> unfollow({
    required String followerId,
    required String targetUserId,
  });

  Stream<bool> watchIsFollowing({
    required String followerId,
    required String targetUserId,
  });

  Future<List<String>> getFollowingIds(String followerId);
}

@LazySingleton(as: FollowRemoteDataSource)
final class FirestoreFollowRemoteDataSource implements FollowRemoteDataSource {
  FirestoreFollowRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _users = 'users';
  static const String _following = 'following';

  DocumentReference<Map<String, dynamic>> _doc(
    String followerId,
    String targetUserId,
  ) => _firestore
      .collection(_users)
      .doc(followerId)
      .collection(_following)
      .doc(targetUserId);

  @override
  Future<void> follow({
    required String followerId,
    required String targetUserId,
  }) async {
    try {
      await _doc(
        followerId,
        targetUserId,
      ).set(<String, dynamic>{'createdAt': FieldValue.serverTimestamp()});
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> unfollow({
    required String followerId,
    required String targetUserId,
  }) async {
    try {
      await _doc(followerId, targetUserId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Stream<bool> watchIsFollowing({
    required String followerId,
    required String targetUserId,
  }) => _doc(followerId, targetUserId).snapshots().map((s) => s.exists);

  @override
  Future<List<String>> getFollowingIds(String followerId) async {
    try {
      final snap = await _firestore
          .collection(_users)
          .doc(followerId)
          .collection(_following)
          .get();
      return snap.docs.map((d) => d.id).toList(growable: false);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }
}
