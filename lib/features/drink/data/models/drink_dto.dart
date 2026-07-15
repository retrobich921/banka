import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/drink.dart';

/// DTO-конверсия `Drink` ↔ Firestore (`drinks/{drinkId}`).
abstract final class DrinkDto {
  const DrinkDto._();

  static const String fName = 'name';
  static const String fBrandId = 'brandId';
  static const String fBrandName = 'brandName';
  static const String fThumbUrl = 'thumbUrl';
  static const String fPostsCount = 'postsCount';
  static const String fRatingSum = 'ratingSum';
  static const String fRatingCount = 'ratingCount';
  static const String fPricesSum = 'pricesSum';
  static const String fPricesCount = 'pricesCount';
  static const String fStores = 'stores';
  static const String fUpdatedAt = 'updatedAt';

  static Drink? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return Drink(
      id: snapshot.id,
      name: (data[fName] as String?) ?? '',
      brandId: data[fBrandId] as String?,
      brandName: data[fBrandName] as String?,
      thumbUrl: data[fThumbUrl] as String?,
      postsCount: (data[fPostsCount] as num?)?.toInt() ?? 0,
      ratingSum: (data[fRatingSum] as num?)?.toDouble() ?? 0,
      ratingCount: (data[fRatingCount] as num?)?.toInt() ?? 0,
      pricesSum: (data[fPricesSum] as num?)?.toDouble() ?? 0,
      pricesCount: (data[fPricesCount] as num?)?.toInt() ?? 0,
      stores: _storesMap(data[fStores]),
      updatedAt: (data[fUpdatedAt] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, int> _storesMap(Object? raw) {
    if (raw is! Map) return const {};
    return {
      for (final e in raw.entries)
        if (e.value is num) e.key.toString(): (e.value as num).toInt(),
    };
  }
}
