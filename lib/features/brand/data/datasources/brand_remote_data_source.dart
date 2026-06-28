import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/brand.dart';
import '../models/brand_dto.dart';

abstract interface class BrandRemoteDataSource {
  Stream<List<Brand>> watchBrands();

  Stream<Brand?> watchBrand(String brandId);

  /// Идемпотентно: ищем по `slug`, если нет — создаём. Возвращает
  /// готовый `Brand` (в т.ч. `id`).
  Future<Brand> ensureBrand({
    required String name,
    String? country,
    String? logoUrl,
  });
}

@LazySingleton(as: BrandRemoteDataSource)
final class FirestoreBrandRemoteDataSource implements BrandRemoteDataSource {
  FirestoreBrandRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _brands = 'brands';
  static const String _posts = 'posts';
  static const String _postBrandIdField = 'brandId';

  CollectionReference<Map<String, dynamic>> get _brandsCol =>
      _firestore.collection(_brands);

  @override
  Stream<List<Brand>> watchBrands() {
    // Денорм-счётчик `brands/{}.postsCount` обновляла Cloud Function, но на
    // Spark-плане функции не выполняются, поэтому в документе он всегда 0.
    // Считаем реальное число постов агрегатным `count()`-запросом по каждому
    // бренду и пересортируем по нему (postsCount desc, name asc). Брендов
    // немного, поэтому N дешёвых count-запросов на эмит допустимы.
    return _brandsCol.orderBy(BrandDto.fName).snapshots().asyncMap((
      snap,
    ) async {
      final brands = snap.docs
          .map(BrandDto.fromSnapshot)
          .whereType<Brand>()
          .toList();

      final withCounts = await Future.wait(
        brands.map((brand) async {
          final agg = await _firestore
              .collection(_posts)
              .where(_postBrandIdField, isEqualTo: brand.id)
              .count()
              .get();
          return brand.copyWith(postsCount: agg.count ?? brand.postsCount);
        }),
      );

      withCounts.sort((a, b) {
        final byCount = b.postsCount.compareTo(a.postsCount);
        if (byCount != 0) return byCount;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      return withCounts;
    });
  }

  @override
  Stream<Brand?> watchBrand(String brandId) {
    // Тот же приём, что и в watchBrands: postsCount в документе всегда 0
    // (Cloud Function на Spark не работает), поэтому считаем реальное число
    // постов агрегатным запросом.
    return _brandsCol.doc(brandId).snapshots().asyncMap((snap) async {
      final brand = BrandDto.fromSnapshot(snap);
      if (brand == null) return null;
      final agg = await _firestore
          .collection(_posts)
          .where(_postBrandIdField, isEqualTo: brand.id)
          .count()
          .get();
      return brand.copyWith(postsCount: agg.count ?? brand.postsCount);
    });
  }

  @override
  Future<Brand> ensureBrand({
    required String name,
    String? country,
    String? logoUrl,
  }) async {
    try {
      final slug = BrandDto.slugify(name);
      if (slug.isEmpty) {
        throw const ServerException(message: 'Имя бренда не может быть пустым');
      }
      final existing = await _brandsCol
          .where(BrandDto.fSlug, isEqualTo: slug)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        return BrandDto.fromMap(
          existing.docs.first.id,
          existing.docs.first.data(),
        );
      }
      final doc = _brandsCol.doc();
      final now = DateTime.now();
      final brand = Brand(
        id: doc.id,
        name: name.trim(),
        slug: slug,
        country: country,
        logoUrl: logoUrl,
        postsCount: 0,
        createdAt: now,
        updatedAt: now,
      );
      await doc.set(BrandDto.toFirestoreMap(brand));
      return brand;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }
}
