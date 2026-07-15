import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../drink/data/models/drink_dto.dart';
import '../../../drink/domain/entities/drink.dart';
import '../../domain/entities/drink_rating.dart';
import '../../domain/entities/drink_type.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/post_ranking.dart';
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
    String? flavorId,
    String? flavorName,
    required List<PostPhoto> photos,
    required DateTime foundDate,
    DrinkRating? rating,
    DrinkType drinkType,
    required String description,
    required List<String> tags,
    String? store,
    double? price,
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

  /// Лента бренда: `where(brandId) + orderBy(createdAt desc)`.
  Stream<List<Post>> watchBrandFeed({
    required String brandId,
    int limit,
    String? startAfterId,
  });

  /// Разовая (не realtime) загрузка следующей страницы ленты для указанного
  /// скоупа. Используется для подгрузки при скролле: дочитываем только
  /// `limit` постов после `startAfterId`, не перечитывая уже загруженные.
  /// Скоуп определяется единственным заданным id (brandId / groupId /
  /// authorId), иначе — глобальная лента.
  Future<List<Post>> fetchFeedPage({
    String? groupId,
    String? brandId,
    String? authorId,
    String? startAfterId,
    int limit,
  });

  Future<void> updatePost({
    required String postId,
    String? drinkName,
    String? brandId,
    String? brandName,
    DateTime? foundDate,
    String? description,
    List<String>? tags,
  });

  Future<void> deletePost(String postId);

  /// Архивирование/восстановление поста (мягкое скрытие из лент).
  Future<void> setArchived({required String postId, required bool archived});

  /// Архив автора: его посты с `archived == true`, свежие сверху.
  Future<List<Post>> fetchArchivedPosts({required String authorId, int limit});

  /// Лента подписок: посты авторов [authorIds] + посты групп [groupIds],
  /// объединённые по `createdAt desc`, без дублей.
  Future<List<Post>> fetchSubscriptionsFeed({
    required List<String> authorIds,
    required List<String> groupIds,
    int limit,
  });

  /// Топ постов: сортировка по `ratingScore` (оценка) либо `likesCount`.
  Future<List<Post>> fetchTopPosts({required PostRanking ranking, int limit});

  /// Sprint 12 — поиск постов по `searchKeywords`-токену + опциональные
  /// фильтры (brandId / groupId). Серверная часть = один `arrayContains`-запрос
  /// (если есть токен) или базовый список по `createdAt desc`; остальные
  /// фильтры применяются на клиенте, чтобы не плодить composite-индексы.
  Future<List<Post>> searchPosts({
    String? token,
    String? brandId,
    String? groupId,
    int limit,
  });
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
    String? flavorId,
    String? flavorName,
    required List<PostPhoto> photos,
    required DateTime foundDate,
    DrinkRating? rating,
    DrinkType drinkType = DrinkType.energy,
    required String description,
    required List<String> tags,
    String? store,
    double? price,
  }) async {
    try {
      final doc = _postsCol.doc();
      final now = DateTime.now();
      final drinkId = drinkKeyOf(brandId: brandId, flavorId: flavorId);
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
        flavorId: flavorId,
        flavorName: flavorName,
        drinkId: drinkId,
        store: (store == null || store.trim().isEmpty) ? null : store.trim(),
        price: price,
        photos: photos,
        foundDate: foundDate,
        rating: rating,
        drinkType: drinkType,
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

      // Карточка напитка (drinks/{drinkId}) — агрегат «РЗТ-стиля»:
      // средняя оценка, счётчик постов, статистика магазинов и цен.
      // Заводится только для постов с выбранными брендом И вкусом —
      // название поста свободное и напиток не идентифицирует.
      if (drinkId != null) {
        final cleanStore = post.store;
        batch.set(
          _firestore.collection('drinks').doc(drinkId),
          <String, dynamic>{
            DrinkDto.fName: drinkDisplayName(
              brandName: brandName,
              flavorName: flavorName,
            ),
            DrinkDto.fBrandId: ?brandId,
            DrinkDto.fBrandName: ?brandName,
            if (photos.isNotEmpty) DrinkDto.fThumbUrl: photos.first.thumbUrl,
            DrinkDto.fPostsCount: FieldValue.increment(1),
            if (rating != null) ...{
              DrinkDto.fRatingSum: FieldValue.increment(rating.score),
              DrinkDto.fRatingCount: FieldValue.increment(1),
            },
            if (price != null) ...{
              DrinkDto.fPricesSum: FieldValue.increment(price),
              DrinkDto.fPricesCount: FieldValue.increment(1),
            },
            if (cleanStore != null)
              DrinkDto.fStores: {cleanStore: FieldValue.increment(1)},
            DrinkDto.fUpdatedAt: Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      }

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
  Stream<List<Post>> watchBrandFeed({
    required String brandId,
    int limit = 20,
    String? startAfterId,
  }) async* {
    Query<Map<String, dynamic>> query = _postsCol
        .where(PostDto.fBrandId, isEqualTo: brandId)
        .orderBy(PostDto.fCreatedAt, descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final cursor = await _postsCol.doc(startAfterId).get();
      if (cursor.exists) query = query.startAfterDocument(cursor);
    }

    yield* query.snapshots().map(_postListFromSnapshot);
  }

  @override
  Future<List<Post>> fetchFeedPage({
    String? groupId,
    String? brandId,
    String? authorId,
    String? startAfterId,
    int limit = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query;
      if (brandId != null) {
        query = _postsCol
            .where(PostDto.fBrandId, isEqualTo: brandId)
            .orderBy(PostDto.fCreatedAt, descending: true);
      } else if (groupId != null) {
        query = _postsCol
            .where(PostDto.fGroupId, isEqualTo: groupId)
            .orderBy(PostDto.fCreatedAt, descending: true);
      } else if (authorId != null) {
        query = _postsCol
            .where(PostDto.fAuthorId, isEqualTo: authorId)
            .orderBy(PostDto.fCreatedAt, descending: true);
      } else {
        query = _postsCol.orderBy(PostDto.fCreatedAt, descending: true);
      }

      if (startAfterId != null) {
        final cursor = await _postsCol.doc(startAfterId).get();
        if (cursor.exists) query = query.startAfterDocument(cursor);
      }

      final snap = await query.limit(limit).get();
      return _postListFromSnapshot(snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> updatePost({
    required String postId,
    String? drinkName,
    String? brandId,
    String? brandName,
    DateTime? foundDate,
    String? description,
    List<String>? tags,
  }) async {
    final updates = <String, dynamic>{
      PostDto.fDrinkName: ?drinkName,
      PostDto.fBrandId: ?brandId,
      PostDto.fBrandName: ?brandName,
      if (foundDate != null) PostDto.fFoundDate: Timestamp.fromDate(foundDate),
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
      final docRef = _postsCol.doc(postId);
      final snap = await docRef.get();
      if (!snap.exists) return;
      final data = snap.data()!;
      final groupId = data[PostDto.fGroupId] as String?;
      final authorId = data[PostDto.fAuthorId] as String?;
      final post = PostDto.fromMap(postId, data);

      // Зеркально createPost: удаляем пост и откатываем denorm-счётчики
      // группы, автора и карточки напитка одним батчем.
      final batch = _firestore.batch()..delete(docRef);
      if (post.drinkId != null && post.drinkId!.isNotEmpty) {
        batch.set(
          _firestore.collection('drinks').doc(post.drinkId),
          <String, dynamic>{
            DrinkDto.fPostsCount: FieldValue.increment(-1),
            if (post.rating != null) ...{
              DrinkDto.fRatingSum: FieldValue.increment(-post.rating!.score),
              DrinkDto.fRatingCount: FieldValue.increment(-1),
            },
            if (post.price != null) ...{
              DrinkDto.fPricesSum: FieldValue.increment(-post.price!),
              DrinkDto.fPricesCount: FieldValue.increment(-1),
            },
            if (post.store != null)
              DrinkDto.fStores: {post.store!: FieldValue.increment(-1)},
            DrinkDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
          },
          SetOptions(merge: true),
        );
      }
      if (groupId != null) {
        batch.update(
          _firestore.collection(_groups).doc(groupId),
          <String, dynamic>{
            'postsCount': FieldValue.increment(-1),
            'updatedAt': Timestamp.fromDate(DateTime.now()),
          },
        );
      }
      if (authorId != null && authorId.isNotEmpty) {
        batch.update(
          _firestore.collection('users').doc(authorId),
          <String, dynamic>{'stats.cansCount': FieldValue.increment(-1)},
        );
      }
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<List<Post>> fetchSubscriptionsFeed({
    required List<String> authorIds,
    required List<String> groupIds,
    int limit = 50,
  }) async {
    try {
      // whereIn ограничен 10 значениями — бьём списки на чанки и сливаем.
      // Дубли (подписан и на автора, и на группу с его постом) убираем по id.
      const chunkSize = 10;
      List<List<String>> chunks(List<String> ids) => [
        for (var i = 0; i < ids.length; i += chunkSize)
          ids.sublist(
            i,
            i + chunkSize > ids.length ? ids.length : i + chunkSize,
          ),
      ];

      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        for (final chunk in chunks(authorIds))
          _postsCol
              .where(PostDto.fAuthorId, whereIn: chunk)
              .orderBy(PostDto.fCreatedAt, descending: true)
              .limit(limit)
              .get(),
        for (final chunk in chunks(groupIds))
          _postsCol
              .where(PostDto.fGroupId, whereIn: chunk)
              .orderBy(PostDto.fCreatedAt, descending: true)
              .limit(limit)
              .get(),
      ];
      if (queries.isEmpty) return const [];

      final snaps = await Future.wait(queries);
      final byId = <String, Post>{};
      for (final snap in snaps) {
        for (final post in _postListFromSnapshot(snap)) {
          byId[post.id] = post;
        }
      }
      final merged = byId.values.toList()
        ..sort((a, b) {
          final ad = a.createdAt;
          final bd = b.createdAt;
          if (ad == null || bd == null) return ad == null ? 1 : -1;
          return bd.compareTo(ad);
        });
      return merged.length > limit ? merged.sublist(0, limit) : merged;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<List<Post>> fetchTopPosts({
    required PostRanking ranking,
    int limit = 50,
  }) async {
    try {
      // topRated: посты без `ratingScore` Firestore автоматически исключает
      // из orderBy — в топ попадают только оценённые.
      final field = switch (ranking) {
        PostRanking.topRated => PostDto.fRatingScore,
        PostRanking.mostLiked => PostDto.fLikesCount,
      };
      final snap = await _postsCol
          .orderBy(field, descending: true)
          .limit(limit)
          .get();
      return _postListFromSnapshot(snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<List<Post>> searchPosts({
    String? token,
    String? brandId,
    String? groupId,
    int limit = 50,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _postsCol;
      if (token != null && token.isNotEmpty) {
        query = query.where(
          PostDto.fSearchKeywords,
          arrayContains: token.toLowerCase(),
        );
      }
      query = query.orderBy(PostDto.fCreatedAt, descending: true).limit(limit);

      final snap = await query.get();
      final posts = _postListFromSnapshot(snap);

      // Дополнительные фильтры применяем на клиенте — Firestore не
      // позволяет дёшево комбинировать `arrayContains` + range +
      // несколько equality на разных полях без отдельных индексов.
      return posts
          .where((p) {
            if (brandId != null && p.brandId != brandId) return false;
            if (groupId != null && p.groupId != groupId) return false;
            return true;
          })
          .toList(growable: false);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> setArchived({
    required String postId,
    required bool archived,
  }) async {
    try {
      await _postsCol.doc(postId).update(<String, dynamic>{
        PostDto.fArchived: archived,
        PostDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<List<Post>> fetchArchivedPosts({
    required String authorId,
    int limit = 50,
  }) async {
    try {
      // Два equality-фильтра — композитный индекс не нужен (merge join);
      // сортируем на клиенте, чтобы не заводить индекс под редкий экран.
      final snap = await _postsCol
          .where(PostDto.fAuthorId, isEqualTo: authorId)
          .where(PostDto.fArchived, isEqualTo: true)
          .limit(limit)
          .get();
      final posts =
          snap.docs.map(PostDto.fromSnapshot).whereType<Post>().toList()
            ..sort((a, b) {
              final ad = a.createdAt;
              final bd = b.createdAt;
              if (ad == null || bd == null) return ad == null ? 1 : -1;
              return bd.compareTo(ad);
            });
      return posts;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  /// Общая распаковка списков постов. Архивные посты отфильтровываются
  /// здесь (единая точка для всех лент/топов/поиска); отдельный экран
  /// архива ходит через [fetchArchivedPosts].
  static List<Post> _postListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(PostDto.fromSnapshot)
        .whereType<Post>()
        .where((p) => !p.archived)
        .toList(growable: false);
  }
}
