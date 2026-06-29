import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_profile.freezed.dart';

/// Полный профиль пользователя — то, что лежит в `users/{uid}` в Firestore.
///
/// В отличие от `AuthUser` (identity-only из feature/auth), `UserProfile`
/// несёт в себе соцсетевые поля: bio, статистику коллекции, FCM-токены и
/// служебные timestamp'ы. Все поля иммутабельны (freezed).
@freezed
sealed class UserProfile with _$UserProfile {
  const factory UserProfile({
    required String id,
    required String displayName,
    required String email,
    String? photoUrl,
    String? bio,

    /// Уникальный username пользователя (3-20 символов: буквы, цифры, подчёркивание)
    @Default('') String username,

    /// Lowercase версия username для case-insensitive поиска и проверки уникальности
    @Default('') String usernameLowercase,

    /// Timestamp последнего изменения username (для cooldown 30 дней)
    DateTime? usernameLastChangedAt,
    @Default(UserStats()) UserStats stats,
    @Default(<String>[]) List<String> fcmTokens,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserProfile;
}

/// Подобъект статистики коллекционера. Изменяется Cloud Function'ами
/// (Sprint 15) при создании/удалении постов и лайков; клиент только читает.
@freezed
sealed class UserStats with _$UserStats {
  const factory UserStats({
    @Default(0) int cansCount,
    @Default(0) int likesReceived,
    @Default(0) int groupsCount,
    String? topBrandId,
  }) = _UserStats;
}
