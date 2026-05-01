import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/post.dart';
import 'post_photo_dto.dart';

/// DTO-конверсия `Post` ↔ Firestore. Имена полей — `posts/{postId}` из
/// `PROJECT_PLAN.md`.
abstract final class PostDto {
  const PostDto._();

  static const String fAuthorId = 'authorId';
  static const String fAuthorName = 'authorName';
  static const String fAuthorPhotoUrl = 'authorPhotoUrl';
  static const String fGroupId = 'groupId';
  static const String fGroupName = 'groupName';
  static const String fBrandId = 'brandId';
  static const String fBrandName = 'brandName';
  static const String fDrinkName = 'drinkName';
  static const String fPhotos = 'photos';
  static const String fFoundDate = 'foundDate';
  static const String fRarity = 'rarity';
  static const String fDescription = 'description';
  static const String fTags = 'tags';
  static const String fLikesCount = 'likesCount';
  static const String fCommentsCount = 'commentsCount';
  static const String fSearchKeywords = 'searchKeywords';
  static const String fCreatedAt = 'createdAt';
  static const String fUpdatedAt = 'updatedAt';

  static Post? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(snapshot.id, data);
  }

  static Post fromMap(String id, Map<String, dynamic> data) {
    return Post(
      id: id,
      authorId: (data[fAuthorId] as String?) ?? '',
      authorName: (data[fAuthorName] as String?) ?? '',
      authorPhotoUrl: data[fAuthorPhotoUrl] as String?,
      groupId: data[fGroupId] as String?,
      groupName: data[fGroupName] as String?,
      brandId: data[fBrandId] as String?,
      brandName: data[fBrandName] as String?,
      drinkName: (data[fDrinkName] as String?) ?? '',
      photos: _photoList(data[fPhotos]),
      foundDate: _timestampToDate(data[fFoundDate]),
      rarity: (data[fRarity] as num?)?.toInt() ?? 1,
      description: (data[fDescription] as String?) ?? '',
      tags: _stringList(data[fTags]),
      likesCount: (data[fLikesCount] as num?)?.toInt() ?? 0,
      commentsCount: (data[fCommentsCount] as num?)?.toInt() ?? 0,
      searchKeywords: _stringList(data[fSearchKeywords]),
      createdAt: _timestampToDate(data[fCreatedAt]),
      updatedAt: _timestampToDate(data[fUpdatedAt]),
    );
  }

  /// Полный snapshot нового поста.
  static Map<String, dynamic> toFirestoreMap(Post post) {
    return <String, dynamic>{
      fAuthorId: post.authorId,
      fAuthorName: post.authorName,
      if (post.authorPhotoUrl != null) fAuthorPhotoUrl: post.authorPhotoUrl,
      if (post.groupId != null) fGroupId: post.groupId,
      if (post.groupName != null) fGroupName: post.groupName,
      if (post.brandId != null) fBrandId: post.brandId,
      if (post.brandName != null) fBrandName: post.brandName,
      fDrinkName: post.drinkName,
      fPhotos: post.photos.map(PostPhotoDto.toMap).toList(growable: false),
      if (post.foundDate != null)
        fFoundDate: Timestamp.fromDate(post.foundDate!),
      fRarity: post.rarity,
      fDescription: post.description,
      fTags: post.tags,
      fLikesCount: post.likesCount,
      fCommentsCount: post.commentsCount,
      fSearchKeywords: post.searchKeywords,
      if (post.createdAt != null)
        fCreatedAt: Timestamp.fromDate(post.createdAt!),
      if (post.updatedAt != null)
        fUpdatedAt: Timestamp.fromDate(post.updatedAt!),
    };
  }

  /// Lowercase-токены для бесплатного поиска через `arrayContains`.
  /// Берём слова длиной ≥ 2 символов из `drinkName` / `brandName` / `tags`.
  static List<String> buildSearchKeywords({
    required String drinkName,
    String? brandName,
    List<String> tags = const <String>[],
  }) {
    final source = <String>[drinkName, ?brandName, ...tags];
    final tokens = <String>{};
    for (final s in source) {
      for (final word in s.toLowerCase().split(RegExp(r'\s+'))) {
        final cleaned = word.replaceAll(RegExp(r'[^a-zа-я0-9]'), '');
        if (cleaned.length >= 2) tokens.add(cleaned);
      }
    }
    return tokens.toList(growable: false);
  }

  static List<PostPhoto> _photoList(Object? raw) {
    if (raw is! List) return const <PostPhoto>[];
    return raw
        .whereType<Map<String, dynamic>>()
        .map(PostPhotoDto.fromMap)
        .toList(growable: false);
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.whereType<String>().toList(growable: false);
  }

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
