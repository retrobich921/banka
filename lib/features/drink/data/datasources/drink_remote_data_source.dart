import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../post/data/models/post_dto.dart';
import '../../../post/domain/entities/post.dart';
import '../../domain/entities/drink.dart';
import '../models/drink_dto.dart';

/// Remote-источник карточек напитков. Сами карточки создаёт/обновляет
/// пост-датасорс (батч при создании поста) — здесь только чтение.
abstract interface class DrinkRemoteDataSource {
  Stream<Drink?> watchDrink(String drinkId);

  /// Топ карточек: берём самые обсуждаемые (postsCount desc), сортировку
  /// по средней оценке делает клиент (avg нельзя посчитать инкрементами).
  /// Лимит щедрый: чарт должен вмещать всю коллекцию, пока напитков
  /// меньше ~500; дальше понадобится пагинация.
  Future<List<Drink>> fetchTopDrinks({int limit});

  /// Посты-«рецензии» напитка, свежие сверху (без архивных).
  Future<List<Post>> fetchDrinkPosts({required String drinkId, int limit});
}

@LazySingleton(as: DrinkRemoteDataSource)
final class FirestoreDrinkRemoteDataSource implements DrinkRemoteDataSource {
  FirestoreDrinkRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _drinks = 'drinks';
  static const String _posts = 'posts';

  @override
  Stream<Drink?> watchDrink(String drinkId) => _firestore
      .collection(_drinks)
      .doc(drinkId)
      .snapshots()
      .map(DrinkDto.fromSnapshot);

  @override
  Future<List<Drink>> fetchTopDrinks({int limit = 500}) async {
    try {
      final snap = await _firestore
          .collection(_drinks)
          .orderBy(DrinkDto.fPostsCount, descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map(DrinkDto.fromSnapshot)
          .whereType<Drink>()
          // Опустевшие карточки (все посты в архиве/удалены) в чарте
          // не показываем.
          .where((d) => d.postsCount > 0)
          .toList(growable: false);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<List<Post>> fetchDrinkPosts({
    required String drinkId,
    int limit = 50,
  }) async {
    try {
      final snap = await _firestore
          .collection(_posts)
          .where(PostDto.fDrinkId, isEqualTo: drinkId)
          .orderBy(PostDto.fCreatedAt, descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map(PostDto.fromSnapshot)
          .whereType<Post>()
          .where((p) => !p.archived)
          .toList(growable: false);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }
}
