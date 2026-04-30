import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_profile.dart';

/// DTO-конверсия `UserProfile` ↔ Firestore.
///
/// Domain-слой не должен видеть `cloud_firestore`, поэтому маппинг живёт здесь
/// (рядом с datasource'ом). Поля схемы — синхронизированы с `PROJECT_PLAN.md`
/// (раздел "users/{userId}").
abstract final class UserProfileDto {
  const UserProfileDto._();

  /// Имена полей в документе `users/{uid}`.
  static const String fDisplayName = 'displayName';
  static const String fEmail = 'email';
  static const String fPhotoUrl = 'photoUrl';
  static const String fBio = 'bio';
  static const String fStats = 'stats';
  static const String fFcmTokens = 'fcmTokens';
  static const String fCreatedAt = 'createdAt';
  static const String fUpdatedAt = 'updatedAt';

  /// Распаковка из `DocumentSnapshot` в `UserProfile`. Если данные `null`
  /// (документ удалён) — возвращает `null`.
  static UserProfile? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(snapshot.id, data);
  }

  /// Чистая распаковка из `Map`. Используется и в Firestore-flow, и в тестах.
  static UserProfile fromMap(String id, Map<String, dynamic> data) {
    return UserProfile(
      id: id,
      displayName: (data[fDisplayName] as String?) ?? '',
      email: (data[fEmail] as String?) ?? '',
      photoUrl: data[fPhotoUrl] as String?,
      bio: data[fBio] as String?,
      stats: _statsFromMap(data[fStats]),
      fcmTokens: ((data[fFcmTokens] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<String>()
          .toList(growable: false),
      createdAt: _timestampToDate(data[fCreatedAt]),
      updatedAt: _timestampToDate(data[fUpdatedAt]),
    );
  }

  /// Сериализация для записи в Firestore. `null`-поля выкидываем, чтобы не
  /// перезаписать существующие значения при `set(merge: true)`.
  static Map<String, dynamic> toFirestoreMap(UserProfile profile) {
    return <String, dynamic>{
      fDisplayName: profile.displayName,
      fEmail: profile.email,
      if (profile.photoUrl != null) fPhotoUrl: profile.photoUrl,
      if (profile.bio != null) fBio: profile.bio,
      fStats: _statsToMap(profile.stats),
      fFcmTokens: profile.fcmTokens,
      if (profile.createdAt != null)
        fCreatedAt: Timestamp.fromDate(profile.createdAt!),
      if (profile.updatedAt != null)
        fUpdatedAt: Timestamp.fromDate(profile.updatedAt!),
    };
  }

  static UserStats _statsFromMap(Object? raw) {
    if (raw is! Map) return const UserStats();
    final map = Map<String, dynamic>.from(raw);
    return UserStats(
      cansCount: (map['cansCount'] as num?)?.toInt() ?? 0,
      likesReceived: (map['likesReceived'] as num?)?.toInt() ?? 0,
      groupsCount: (map['groupsCount'] as num?)?.toInt() ?? 0,
      avgRarity: (map['avgRarity'] as num?)?.toDouble() ?? 0.0,
      topBrandId: map['topBrandId'] as String?,
    );
  }

  static Map<String, dynamic> _statsToMap(UserStats stats) => <String, dynamic>{
    'cansCount': stats.cansCount,
    'likesReceived': stats.likesReceived,
    'groupsCount': stats.groupsCount,
    'avgRarity': stats.avgRarity,
    if (stats.topBrandId != null) 'topBrandId': stats.topBrandId,
  };

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
