import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/flavor.dart';
import '../models/flavor_dto.dart';

abstract interface class FlavorRemoteDataSource {
  Stream<List<Flavor>> watchFlavors(String brandId);

  Future<Flavor> createFlavor({required String brandId, required String name});
}

@LazySingleton(as: FlavorRemoteDataSource)
final class FirestoreFlavorRemoteDataSource implements FlavorRemoteDataSource {
  FirestoreFlavorRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _brands = 'brands';
  static const String _flavors = 'flavors';

  CollectionReference<Map<String, dynamic>> _flavorsCol(String brandId) =>
      _firestore.collection(_brands).doc(brandId).collection(_flavors);

  @override
  Stream<List<Flavor>> watchFlavors(String brandId) {
    return _flavorsCol(brandId)
        .orderBy(FlavorDto.fName)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) =>
                    FlavorDto.fromSnapshot(brandId: brandId, snapshot: doc),
              )
              .whereType<Flavor>()
              .toList(growable: false),
        );
  }

  @override
  Future<Flavor> createFlavor({
    required String brandId,
    required String name,
  }) async {
    try {
      final doc = _flavorsCol(brandId).doc();
      final flavor = Flavor(
        id: doc.id,
        brandId: brandId,
        name: name.trim(),
        createdAt: DateTime.now(),
      );
      await doc.set(FlavorDto.toFirestoreMap(flavor));
      return flavor;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }
}
