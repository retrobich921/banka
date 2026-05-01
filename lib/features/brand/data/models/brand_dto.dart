import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/brand.dart';

/// DTO-конверсия `Brand` ↔ Firestore. Имена полей — `brands/{brandId}`
/// из `PROJECT_PLAN.md`.
abstract final class BrandDto {
  const BrandDto._();

  static const String fName = 'name';
  static const String fSlug = 'slug';
  static const String fLogoUrl = 'logoUrl';
  static const String fCountry = 'country';
  static const String fPostsCount = 'postsCount';
  static const String fCreatedAt = 'createdAt';
  static const String fUpdatedAt = 'updatedAt';

  static Brand? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(snapshot.id, data);
  }

  static Brand fromMap(String id, Map<String, dynamic> data) {
    return Brand(
      id: id,
      name: (data[fName] as String?) ?? '',
      slug: (data[fSlug] as String?) ?? '',
      logoUrl: data[fLogoUrl] as String?,
      country: data[fCountry] as String?,
      postsCount: (data[fPostsCount] as num?)?.toInt() ?? 0,
      createdAt: _timestampToDate(data[fCreatedAt]),
      updatedAt: _timestampToDate(data[fUpdatedAt]),
    );
  }

  static Map<String, dynamic> toFirestoreMap(Brand brand) {
    return <String, dynamic>{
      fName: brand.name,
      fSlug: brand.slug,
      if (brand.logoUrl != null) fLogoUrl: brand.logoUrl,
      if (brand.country != null) fCountry: brand.country,
      fPostsCount: brand.postsCount,
      if (brand.createdAt != null)
        fCreatedAt: Timestamp.fromDate(brand.createdAt!),
      if (brand.updatedAt != null)
        fUpdatedAt: Timestamp.fromDate(brand.updatedAt!),
    };
  }

  /// Превращает «Monster Energy®» → `monster-energy`.
  static String slugify(String name) {
    final lower = name.toLowerCase().trim();
    final cleaned = lower.replaceAll(RegExp(r'[^a-zа-я0-9\s-]'), '');
    final dashed = cleaned.replaceAll(RegExp(r'\s+'), '-');
    return dashed
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
