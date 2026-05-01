import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/post.dart';
import '../models/post_dto.dart';

/// Контракт remote-источника для постов. Бросает `ServerException` при
/// сбоях Firestore — repository оборачивает их в `Failure`.
abstract interface class PostRemoteDataSource {
  Future<Post> createPost({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String drinkName,
    String? groupId,
    String? groupName,
    String? brandId,
    String? brandName,
    required List<PostPhoto> photos,
    required DateTime foundDate,
    required int rarity,
    required String description,
    required List<String> tags,
  });

  Future<Post?> getPost(String postId);

  Stream<Post?> watchPost(String postId);

  Stream<List<Post>> watchFeed({int limit, String? startAfterId});

  Stream<List<Post>> watchGroupFeed({
    required String groupId,
    int limit,
    String? startAfterId,
  });

  Stream<List<Post>> watchAuthorFeed({
    required String authorId,
    int limit,
    String? startAfterId,
  });

  Future<void> updatePost({
    required String postId,
    String? drinkName,
    String? brandId,
    String? brandName,
    DateTime? foundDate,
    int? rarity,
    String? description,
    List<String>? tags,
  });

  Future<void> deletePost(String postId);
}

@LazySingleton(as: PostRemoteDataSource)
final class FirestorePostRemoteDataSource implements PostRemoteDataSource {
  FirestorePostRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _posts = 'posts';
  static const String _groups = 'groups';

  CollectionReference<Map<String, dynamic>> get _postsCol =>
      _firestore.collection(_posts);

  @override
  Future<Post> createPost({
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String drinkName,
    String? groupId,
    String? groupName,
    String? brandId,
    String? brandName,
    required List<PostPhoto> photos,
    required DateTime foundDate,
    required int rarity,
    required String description,
    required List<String> tags,
  }) async {
    try {
      final doc = _postsCol.doc();
      final now = DateTime.now();
      final post = Post(
        id: doc.id,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        drinkName: drinkName,
        groupId: groupId,
        groupName: groupName,
        brandId: brandId,
        brandName: brandName,
        photos: photos,
        foundDate: foundDate,
        rarity: rarity,
        description: description,
        tags: tags,
        likesCount: 0,
        commentsCount: 0,
        searchKeywords: PostDto.buildSearchKeywords(
          drinkName: drinkName,
          brandName: brandName,
          tags: tags,
        ),
        createdAt: now,
        updatedAt: now,
      );

      // Атомарно: создаём пост + инкрементим denorm-счётчики на группе и
      // юзере. Если транзакция отвалится — всё откатится.
      final batch = _firestore.batch()..set(doc, PostDto.toFirestoreMap(post));
      if (groupId != null) {
        batch.update(
          _firestore.collection(_groups).doc(groupId),
          <String, dynamic>{
            'postsCount': FieldValue.increment(1),
            'updatedAt': Timestamp.fromDate(now),
          },
        );
      }
      batch.update(
        _firestore.collection('users').doc(authorId),
        <String, dynamic>{'stats.cansCount': FieldValue.increment(1)},
      );

      await batch.commit();
      return post;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<Post?> getPost(String postId) async {
    try {
      final snap = await _postsCol.doc(postId).get();
      return PostDto.fromSnapshot(snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Stream<Post?> watchPost(String postId) =>
      _postsCol.doc(postId).snapshots().map(PostDto.fromSnapshot);

  @override
  Stream<List<Post>> watchFeed({int limit = 20, String? startAfterId}) async* {
    Query<Map<String, dynamic>> query = _postsCol
        .orderBy(PostDto.fCreatedAt, descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final cursor = await _postsCol.doc(startAfterId).get();
      if (cursor.exists) query = query.startAfterDocument(cursor);
    }

    yield* query.snapshots().map(_postListFromSnapshot);
  }

  @override
  Stream<List<Post>> watchGroupFeed({
    required String groupId,
    int limit = 20,
    String? startAfterId,
  }) async* {
    Query<Map<String, dynamic>> query = _postsCol
        .where(PostDto.fGroupId, isEqualTo: groupId)
        .orderBy(PostDto.fCreatedAt, descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final cursor = await _postsCol.doc(startAfterId).get();
      if (cursor.exists) query = query.startAfterDocument(cursor);
    }

    yield* query.snapshots().map(_postListFromSnapshot);
  }

  @override
  Stream<List<Post>> watchAuthorFeed({
    required String authorId,
    int limit = 20,
    String? startAfterId,
  }) async* {
    Query<Map<String, dynamic>> query = _postsCol
        .where(PostDto.fAuthorId, isEqualTo: authorId)
        .orderBy(PostDto.fCreatedAt, descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final cursor = await _postsCol.doc(startAfterId).get();
      if (cursor.exists) query = query.startAfterDocument(cursor);
    }

    yield* query.snapshots().map(_postListFromSnapshot);
  }

  @override
  Future<void> updatePost({
    required String postId,
    String? drinkName,
    String? brandId,
    String? brandName,
    DateTime? foundDate,
    int? rarity,
    String? description,
    List<String>? tags,
  }) async {
    final updates = <String, dynamic>{
      PostDto.fDrinkName: ?drinkName,
      PostDto.fBrandId: ?brandId,
      PostDto.fBrandName: ?brandName,
      if (foundDate != null) PostDto.fFoundDate: Timestamp.fromDate(foundDate),
      PostDto.fRarity: ?rarity,
      PostDto.fDescription: ?description,
      PostDto.fTags: ?tags,
    };
    if (updates.isEmpty) return;
    if (drinkName != null || brandName != null || tags != null) {
      // Любое из этих полей меняет токены поиска — пересчитываем.
      // Получаем текущий пост, чтобы заполнить недостающие поля.
      final current = await getPost(postId);
      if (current != null) {
        updates[PostDto.fSearchKeywords] = PostDto.buildSearchKeywords(
          drinkName: drinkName ?? current.drinkName,
          brandName: brandName ?? current.brandName,
          tags: tags ?? current.tags,
        );
      }
    }
    updates[PostDto.fUpdatedAt] = Timestamp.fromDate(DateTime.now());
    try {
      await _postsCol.doc(postId).update(updates);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      await _postsCol.doc(postId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  static List<Post> _postListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(PostDto.fromSnapshot)
        .whereType<Post>()
        .toList(growable: false);
  }
}
