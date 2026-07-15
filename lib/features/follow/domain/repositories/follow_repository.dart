import '../../../../core/utils/typedefs.dart';

/// Подписки пользователя на других пользователей (VK-style follow).
///
/// Хранение: `users/{followerId}/following/{targetUserId}` — документ-маркер
/// с `createdAt`. Подписка на группы отдельно не хранится: «подписан на
/// группу» = состоит в ней (`groups.membersUids`).
abstract interface class FollowRepository {
  ResultFuture<void> follow({
    required String followerId,
    required String targetUserId,
  });

  ResultFuture<void> unfollow({
    required String followerId,
    required String targetUserId,
  });

  /// Live-флаг «подписан ли `followerId` на `targetUserId`».
  ResultStream<bool> watchIsFollowing({
    required String followerId,
    required String targetUserId,
  });

  /// Разовый список id пользователей, на которых подписан `followerId`.
  ResultFuture<List<String>> getFollowingIds(String followerId);
}
