import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/drink_rating.dart';
import '../../domain/entities/drink_type.dart';
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
  static const String fFlavorId = 'flavorId';
  static const String fFlavorName = 'flavorName';
  static const String fDrinkId = 'drinkId';
  static const String fStore = 'store';
  static const String fPrice = 'price';
  static const String fDrinkName = 'drinkName';
  static const String fPhotos = 'photos';
  static const String fFoundDate = 'foundDate';
  static const String fRating = 'rating';
  static const String fRatingScore = 'ratingScore';
  static const String fDrinkType = 'drinkType';
  static const String fDescription = 'description';
  static const String fTags = 'tags';
  static const String fLikesCount = 'likesCount';
  static const String fCommentsCount = 'commentsCount';
  static const String fArchived = 'archived';
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
      flavorId: data[fFlavorId] as String?,
      flavorName: data[fFlavorName] as String?,
      drinkId: data[fDrinkId] as String?,
      store: data[fStore] as String?,
      price: (data[fPrice] as num?)?.toDouble(),
      drinkName: (data[fDrinkName] as String?) ?? '',
      photos: _photoList(data[fPhotos]),
      foundDate: _timestampToDate(data[fFoundDate]),
      rating: _ratingFromMap(data[fRating]),
      drinkType: DrinkType.fromKey(data[fDrinkType] as String?),
      description: (data[fDescription] as String?) ?? '',
      tags: _stringList(data[fTags]),
      likesCount: (data[fLikesCount] as num?)?.toInt() ?? 0,
      commentsCount: (data[fCommentsCount] as num?)?.toInt() ?? 0,
      // Легаси-документы без поля — не в архиве.
      archived: (data[fArchived] as bool?) ?? false,
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
      if (post.flavorId != null) fFlavorId: post.flavorId,
      if (post.flavorName != null) fFlavorName: post.flavorName,
      if (post.drinkId != null) fDrinkId: post.drinkId,
      if (post.store != null) fStore: post.store,
      if (post.price != null) fPrice: post.price,
      fDrinkName: post.drinkName,
      fPhotos: post.photos.map(PostPhotoDto.toMap).toList(growable: false),
      if (post.foundDate != null)
        fFoundDate: Timestamp.fromDate(post.foundDate!),
      if (post.rating != null) fRating: _ratingToMap(post.rating!),
      if (post.rating != null) fRatingScore: post.rating!.score,
      fDrinkType: post.drinkType.storageKey,
      fDescription: post.description,
      fTags: post.tags,
      fLikesCount: post.likesCount,
      fCommentsCount: post.commentsCount,
      fArchived: post.archived,
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

  static DrinkRating? _ratingFromMap(Object? raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    int v(String k) => (map[k] as num?)?.toInt().clamp(1, 10) ?? 5;
    return DrinkRating(
      taste: v('taste'),
      balance: v('balance'),
      texture: v('texture'),
      aftertaste: v('aftertaste'),
      design: v('design'),
      vibe: v('vibe'),
    );
  }

  static Map<String, dynamic> _ratingToMap(DrinkRating r) => <String, dynamic>{
    'taste': r.taste,
    'balance': r.balance,
    'texture': r.texture,
    'aftertaste': r.aftertaste,
    'design': r.design,
    'vibe': r.vibe,
  };

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
