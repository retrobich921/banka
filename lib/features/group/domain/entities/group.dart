import 'package:freezed_annotation/freezed_annotation.dart';

part 'group.freezed.dart';

/// Тематическая группа / коллекция, в которую пользователи постят банки.
///
/// Соответствует документу `groups/{groupId}` из `PROJECT_PLAN.md`.
/// Поля `membersCount` и `postsCount` — денормализованные счётчики
/// (обновляются из Cloud Functions либо транзакционно). `membersUids` —
/// денормализованный массив для быстрого запроса «мои группы»
/// (`where('membersUids', arrayContains, uid)`); ограничение Firestore
/// на массив-where ~30k значений, на практике до сотен участников держим
/// тут, для крупных сообществ переедем на отдельный индекс-документ.
@freezed
sealed class Group with _$Group {
  const factory Group({
    required String id,
    required String name,
    required String ownerId,
    required bool isPublic,
    @Default('') String description,
    String? coverUrl,
    @Default(0) int membersCount,
    @Default(0) int postsCount,
    @Default(<String>[]) List<String> tags,
    @Default(<String>[]) List<String> membersUids,

    /// Кто может публиковать посты в группу.
    @Default(GroupPostingPolicy.all) GroupPostingPolicy postingPolicy,

    /// Денорм-список uid админов (владелец сюда не входит — он проверяется
    /// по `ownerId`). Нужен для дешёвой проверки «могу ли постить» без
    /// чтения member-документа.
    @Default(<String>[]) List<String> adminsUids,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Group;
}

/// Политика публикации постов в группе.
enum GroupPostingPolicy {
  /// Постить может любой участник (поведение по умолчанию, как раньше).
  all,

  /// Постить могут только владелец и админы; остальные — подписчики.
  admins;

  static GroupPostingPolicy fromKey(String? key) => switch (key) {
    'admins' => GroupPostingPolicy.admins,
    _ => GroupPostingPolicy.all,
  };

  String get key => switch (this) {
    GroupPostingPolicy.all => 'all',
    GroupPostingPolicy.admins => 'admins',
  };
}

extension GroupPermissions on Group {
  /// Может ли [userId] публиковать посты в эту группу.
  bool canPost(String userId) =>
      postingPolicy == GroupPostingPolicy.all ||
      ownerId == userId ||
      adminsUids.contains(userId);
}

enum GroupRole { owner, admin, member }

/// Документ `groups/{groupId}/members/{userId}`.
@freezed
sealed class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String userId,
    required String groupId,
    @Default(GroupRole.member) GroupRole role,
    @Default('') String displayName,
    DateTime? joinedAt,
  }) = _GroupMember;
}

/// Запрос на вступление в закрытую группу.
/// Документ `groups/{groupId}/join_requests/{userId}`.
@freezed
sealed class JoinRequest with _$JoinRequest {
  const factory JoinRequest({
    required String userId,
    required String groupId,
    @Default(JoinRequestStatus.pending) JoinRequestStatus status,
    @Default('') String displayName,
    @Default('') String groupOwnerId,
    DateTime? requestedAt,
    DateTime? respondedAt,
  }) = _JoinRequest;
}

enum JoinRequestStatus { pending, approved, rejected }
