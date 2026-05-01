import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/comment.dart';

/// DTO-конверсия `Comment` ↔ Firestore. Имена полей —
/// `posts/{postId}/comments/{commentId}` из `PROJECT_PLAN.md`.
abstract final class CommentDto {
  const CommentDto._();

  static const String fAuthorId = 'authorId';
  static const String fAuthorName = 'authorName';
  static const String fAuthorPhotoUrl = 'authorPhotoUrl';
  static const String fText = 'text';
  static const String fCreatedAt = 'createdAt';

  static Comment? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(snapshot.id, data);
  }

  static Comment fromMap(String id, Map<String, dynamic> data) {
    return Comment(
      id: id,
      authorId: (data[fAuthorId] as String?) ?? '',
      authorName: (data[fAuthorName] as String?) ?? '',
      authorPhotoUrl: data[fAuthorPhotoUrl] as String?,
      text: (data[fText] as String?) ?? '',
      createdAt: _timestampToDate(data[fCreatedAt]),
    );
  }

  /// Snapshot нового комментария — пишем в `add()` при `addComment`.
  static Map<String, dynamic> toFirestoreMap(Comment comment) {
    return <String, dynamic>{
      fAuthorId: comment.authorId,
      fAuthorName: comment.authorName,
      if (comment.authorPhotoUrl != null)
        fAuthorPhotoUrl: comment.authorPhotoUrl,
      fText: comment.text,
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
