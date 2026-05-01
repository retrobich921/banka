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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Group;
}

enum GroupRole { owner, admin, member }

/// Документ `groups/{groupId}/members/{userId}`.
@freezed
sealed class GroupMember with _$GroupMember {
  const factory GroupMember({
    required String userId,
    required String groupId,
    @Default(GroupRole.member) GroupRole role,
    DateTime? joinedAt,
  }) = _GroupMember;
}
