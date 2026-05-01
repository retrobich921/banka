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

  CollectionReference<Map<String, dynamic>> get _brandsCol =>
      _firestore.collection(_brands);

  @override
  Stream<List<Brand>> watchBrands() {
    return _brandsCol
        .orderBy(BrandDto.fPostsCount, descending: true)
        .orderBy(BrandDto.fName)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(BrandDto.fromSnapshot)
              .whereType<Brand>()
              .toList(growable: false),
        );
  }

  @override
  Stream<Brand?> watchBrand(String brandId) =>
      _brandsCol.doc(brandId).snapshots().map(BrandDto.fromSnapshot);

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
