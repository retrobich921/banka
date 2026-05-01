import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';

/// Контракт работы с группами и членством. Все методы возвращают
/// `Either<Failure, T>` через `ResultFuture` / `ResultStream`.
abstract interface class GroupRepository {
  /// Создать группу. Создатель автоматически становится `owner` и первым
  /// участником (атомарно: документ группы + member-doc + denorm-массив).
  ResultFuture<Group> createGroup({
    required String ownerId,
    required String name,
    String description,
    bool isPublic,
    List<String> tags,
    String? coverUrl,
  });

  ResultFuture<Group?> getGroup(String groupId);

  ResultStream<Group?> watchGroup(String groupId);

  /// Real-time список групп, в которых юзер состоит. Сортировка по
  /// `updatedAt desc` (свежее активные сверху).
  ResultStream<List<Group>> watchMyGroups(String userId);

  /// Real-time витрина публичных групп. Сортировка по `postsCount desc`,
  /// пагинация — через [startAfterId] (id последнего видимого).
  ResultStream<List<Group>> watchPublicGroups({
    int limit,
    String? startAfterId,
  });

  ResultFuture<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool? isPublic,
    String? coverUrl,
    List<String>? tags,
  });

  /// Удаление группы — только владельцем (проверка в Security Rules).
  /// На клиенте удаляем только сам документ; чистка members + постов —
  /// Cloud Function (Sprint 18).
  ResultFuture<void> deleteGroup(String groupId);

  ResultFuture<void> joinGroup({
    required String groupId,
    required String userId,
  });

  ResultFuture<void> leaveGroup({
    required String groupId,
    required String userId,
  });

  ResultStream<List<GroupMember>> watchGroupMembers(String groupId);

  ResultFuture<GroupMember?> getMembership({
    required String groupId,
    required String userId,
  });
}
