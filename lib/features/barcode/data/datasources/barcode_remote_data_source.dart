import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/barcode.dart';
import '../models/barcode_dto.dart';

abstract interface class BarcodeRemoteDataSource {
  Future<Barcode?> lookupBarcode(String code);

  Future<Barcode> saveBarcode({
    required String code,
    required String drinkName,
    required String contributedBy,
    String? brandId,
    String? brandName,
    String? suggestedPhotoUrl,
  });
}

@LazySingleton(as: BarcodeRemoteDataSource)
final class FirestoreBarcodeRemoteDataSource
    implements BarcodeRemoteDataSource {
  FirestoreBarcodeRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _barcodes = 'barcodes';

  CollectionReference<Map<String, dynamic>> get _barcodesCol =>
      _firestore.collection(_barcodes);

  @override
  Future<Barcode?> lookupBarcode(String code) async {
    try {
      final id = BarcodeDto.normalize(code);
      if (id.isEmpty) {
        throw const ServerException(message: 'Пустой штрих-код');
      }
      final snap = await _barcodesCol.doc(id).get();
      if (!snap.exists) return null;
      return BarcodeDto.fromSnapshot(snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<Barcode> saveBarcode({
    required String code,
    required String drinkName,
    required String contributedBy,
    String? brandId,
    String? brandName,
    String? suggestedPhotoUrl,
  }) async {
    try {
      final id = BarcodeDto.normalize(code);
      if (id.isEmpty) {
        throw const ServerException(message: 'Пустой штрих-код');
      }
      if (drinkName.trim().isEmpty) {
        throw const ServerException(
          message: 'drinkName обязателен для contribute',
        );
      }
      final ref = _barcodesCol.doc(id);
      // Идемпотентный contribute-back: ставим основные поля + первичные
      // (`contributedBy/createdAt`) через `setOptions(merge: true)`. Если
      // документ уже существует — основные поля обновятся, первичные
      // защищены security rules и server timestamps.
      final payload = <String, dynamic>{
        BarcodeDto.fDrinkName: drinkName.trim(),
        BarcodeDto.fBrandId: ?brandId,
        BarcodeDto.fBrandName: ?brandName,
        BarcodeDto.fSuggestedPhotoUrl: ?suggestedPhotoUrl,
        BarcodeDto.fContributedBy: contributedBy,
        BarcodeDto.fCreatedAt: FieldValue.serverTimestamp(),
      };
      await ref.set(payload, SetOptions(merge: true));

      final snap = await ref.get();
      return BarcodeDto.fromSnapshot(snap) ??
          Barcode(
            id: id,
            drinkName: drinkName.trim(),
            brandId: brandId,
            brandName: brandName,
            suggestedPhotoUrl: suggestedPhotoUrl,
            contributedBy: contributedBy,
            createdAt: DateTime.now(),
          );
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }
}
