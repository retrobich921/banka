import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/like.dart';

/// DTO-конверсия `Like` ↔ Firestore. Имена полей — `posts/{postId}/likes/{userId}`
/// из `PROJECT_PLAN.md`.
abstract final class LikeDto {
  const LikeDto._();

  static const String fUserName = 'userName';
  static const String fUserPhotoUrl = 'userPhotoUrl';
  static const String fCreatedAt = 'createdAt';

  static Like? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(snapshot.id, data);
  }

  static Like fromMap(String userId, Map<String, dynamic> data) {
    return Like(
      userId: userId,
      userName: (data[fUserName] as String?) ?? '',
      userPhotoUrl: data[fUserPhotoUrl] as String?,
      createdAt: _timestampToDate(data[fCreatedAt]),
    );
  }

  /// Snapshot нового лайка — пишем в `set()` при `likePost`.
  static Map<String, dynamic> toFirestoreMap(Like like) {
    return <String, dynamic>{
      fUserName: like.userName,
      if (like.userPhotoUrl != null) fUserPhotoUrl: like.userPhotoUrl,
      fCreatedAt: FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
