import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/barcode.dart';

/// DTO-конверсия `Barcode` ↔ Firestore (`barcodes/{ean}`).
///
/// Имена полей соответствуют схеме из `PROJECT_PLAN.md`. `id`
/// документа = сам EAN, поэтому в `toFirestoreMap` оно не пишется.
abstract final class BarcodeDto {
  const BarcodeDto._();

  static const String fDrinkName = 'drinkName';
  static const String fBrandId = 'brandId';
  static const String fBrandName = 'brandName';
  static const String fSuggestedPhotoUrl = 'suggestedPhotoUrl';
  static const String fContributedBy = 'contributedBy';
  static const String fCreatedAt = 'createdAt';

  static Barcode? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) return null;
    return fromMap(snap.id, data);
  }

  static Barcode fromMap(String id, Map<String, dynamic> data) {
    return Barcode(
      id: id,
      drinkName: (data[fDrinkName] as String?) ?? '',
      brandId: data[fBrandId] as String?,
      brandName: data[fBrandName] as String?,
      suggestedPhotoUrl: data[fSuggestedPhotoUrl] as String?,
      contributedBy: data[fContributedBy] as String?,
      createdAt: _timestampToDate(data[fCreatedAt]),
    );
  }

  /// Только для первичной записи: повторные `set(merge: true)` не
  /// должны затирать `contributedBy/createdAt`. Поэтому при contribute-
  /// back из datasource эти поля выставляются явно через
  /// `FieldValue.serverTimestamp()` — здесь же мы лишь готовим основные
  /// поля для merge-записи.
  static Map<String, dynamic> toFirestoreMap(Barcode barcode) {
    return <String, dynamic>{
      fDrinkName: barcode.drinkName,
      fBrandId: ?barcode.brandId,
      fBrandName: ?barcode.brandName,
      fSuggestedPhotoUrl: ?barcode.suggestedPhotoUrl,
    };
  }

  /// Нормализуем штрих-код: оставляем только цифры (mobile_scanner может
  /// отдавать с пробелами). Для EAN-13/UPC это безопасно — там только
  /// арабские цифры.
  static String normalize(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '').trim();

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
