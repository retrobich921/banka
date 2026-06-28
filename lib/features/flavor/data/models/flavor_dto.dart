import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/flavor.dart';

/// DTO-конверсия `Flavor` ↔ Firestore.
abstract final class FlavorDto {
  const FlavorDto._();

  static const String fName = 'name';
  static const String fBrandId = 'brandId';
  static const String fCreatedAt = 'createdAt';

  static Flavor? fromSnapshot({
    required String brandId,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(brandId: brandId, id: snapshot.id, data: data);
  }

  static Flavor fromMap({
    required String brandId,
    required String id,
    required Map<String, dynamic> data,
  }) {
    return Flavor(
      id: id,
      brandId: brandId,
      name: (data[fName] as String?) ?? '',
      createdAt: _timestampToDate(data[fCreatedAt]),
    );
  }

  static Map<String, dynamic> toFirestoreMap(Flavor flavor) {
    return <String, dynamic>{
      fName: flavor.name,
      fBrandId: flavor.brandId,
      if (flavor.createdAt != null)
        fCreatedAt: Timestamp.fromDate(flavor.createdAt!),
    };
  }

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
