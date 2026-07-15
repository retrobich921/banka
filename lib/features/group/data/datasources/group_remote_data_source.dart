import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/group.dart';
import '../models/group_dto.dart';
import '../models/group_member_dto.dart';
import '../models/join_request_dto.dart';

/// Контракт remote-источника для групп. Бросает `ServerException` при
/// сбоях Firestore — repository оборачивает их в `Failure`.
abstract interface class GroupRemoteDataSource {
  Future<Group> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required bool isPublic,
    required List<String> tags,
    String? coverUrl,
    GroupPostingPolicy postingPolicy,
  });

  Future<Group?> getGroup(String groupId);

  Stream<Group?> watchGroup(String groupId);

  Stream<List<Group>> watchMyGroups(String userId);

  Stream<List<Group>> watchPublicGroups({int limit, String? startAfterId});

  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool? isPublic,
    String? coverUrl,
    List<String>? tags,
  });

  Future<void> deleteGroup(String groupId);

  Future<void> joinGroup({
    required String groupId,
    required String userId,
    required String displayName,
  });

  Future<void> leaveGroup({required String groupId, required String userId});

  Stream<List<GroupMember>> watchGroupMembers(String groupId);

  Future<GroupMember?> getMembership({
    required String groupId,
    required String userId,
  });

  /// Назначить/снять админа: роль в member-документе + денорм `adminsUids`.
  Future<void> setMemberRole({
    required String groupId,
    required String userId,
    required GroupRole role,
  });

  /// Создать запрос на вступление в закрытую группу
  Future<void> requestJoin({
    required String groupId,
    required String userId,
    required String displayName,
  });

  /// Одобрить запрос на вступление (только для владельца/админа)
  Future<void> approveJoinRequest({
    required String groupId,
    required String userId,
  });

  /// Отклонить запрос на вступление
  Future<void> rejectJoinRequest({
    required String groupId,
    required String userId,
  });

  /// Получить запрос на вступление конкретного пользователя
  Future<JoinRequest?> getJoinRequest({
    required String groupId,
    required String userId,
  });

  /// Подписка на запросы на вступление (для владельца)
  Stream<List<JoinRequest>> watchJoinRequests(String groupId);
}

/// Firestore-реализация. Атомарность создания / join / leave обеспечивается
/// `WriteBatch` (групповой документ + member-документ + denorm-массив
/// `membersUids`).
@LazySingleton(as: GroupRemoteDataSource)
final class FirestoreGroupRemoteDataSource implements GroupRemoteDataSource {
  FirestoreGroupRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _groups = 'groups';
  static const String _members = 'members';
  static const String _joinRequests = 'join_requests';

  CollectionReference<Map<String, dynamic>> get _groupsCol =>
      _firestore.collection(_groups);

  CollectionReference<Map<String, dynamic>> _membersCol(String groupId) =>
      _groupsCol.doc(groupId).collection(_members);

  CollectionReference<Map<String, dynamic>> _joinRequestsCol(String groupId) =>
      _groupsCol.doc(groupId).collection(_joinRequests);

  @override
  Future<Group> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required bool isPublic,
    required List<String> tags,
    String? coverUrl,
    GroupPostingPolicy postingPolicy = GroupPostingPolicy.all,
  }) async {
    try {
      final doc = _groupsCol.doc();
      final now = DateTime.now();
      final group = Group(
        id: doc.id,
        name: name,
        ownerId: ownerId,
        isPublic: isPublic,
        description: description,
        coverUrl: coverUrl,
        membersCount: 1,
        postsCount: 0,
        tags: tags,
        membersUids: [ownerId],
        postingPolicy: postingPolicy,
        createdAt: now,
        updatedAt: now,
      );
      final ownerMember = GroupMember(
        userId: ownerId,
        groupId: doc.id,
        role: GroupRole.owner,
        displayName: '', // TODO: передавать displayName владельца
        joinedAt: now,
      );
      final batch = _firestore.batch()
        ..set(doc, GroupDto.toFirestoreMap(group))
        ..set(
          _membersCol(doc.id).doc(ownerId),
          GroupMemberDto.toFirestoreMap(ownerMember),
        );
      await batch.commit();
      return group;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<Group?> getGroup(String groupId) async {
    try {
      final snap = await _groupsCol.doc(groupId).get();
      return GroupDto.fromSnapshot(snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Stream<Group?> watchGroup(String groupId) =>
      _groupsCol.doc(groupId).snapshots().map(GroupDto.fromSnapshot);

  @override
  Stream<List<Group>> watchMyGroups(String userId) {
    return _groupsCol
        .where(GroupDto.fMembersUids, arrayContains: userId)
        .orderBy(GroupDto.fUpdatedAt, descending: true)
        .snapshots()
        .map(_groupListFromSnapshot);
  }

  @override
  Stream<List<Group>> watchPublicGroups({
    int limit = 20,
    String? startAfterId,
  }) async* {
    // Показываем все группы (и публичные, и закрытые)
    // Сортируем по количеству постов
    Query<Map<String, dynamic>> query = _groupsCol
        .orderBy(GroupDto.fPostsCount, descending: true)
        .limit(limit);

    if (startAfterId != null) {
      final cursor = await _groupsCol.doc(startAfterId).get();
      if (cursor.exists) {
        query = query.startAfterDocument(cursor);
      }
    }

    yield* query.snapshots().map(_groupListFromSnapshot);
  }

  @override
  Future<void> updateGroup({
    required String groupId,
    String? name,
    String? description,
    bool? isPublic,
    String? coverUrl,
    List<String>? tags,
  }) async {
    final updates = <String, dynamic>{
      GroupDto.fName: ?name,
      GroupDto.fDescription: ?description,
      GroupDto.fIsPublic: ?isPublic,
      GroupDto.fCoverUrl: ?coverUrl,
      GroupDto.fTags: ?tags,
    };
    if (updates.isEmpty) return;
    updates[GroupDto.fUpdatedAt] = Timestamp.fromDate(DateTime.now());
    try {
      await _groupsCol.doc(groupId).update(updates);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      await _groupsCol.doc(groupId).delete();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> joinGroup({
    required String groupId,
    required String userId,
    required String displayName,
  }) async {
    try {
      // Используем транзакцию для безопасного обновления
      await _firestore.runTransaction((transaction) async {
        final groupDoc = _groupsCol.doc(groupId);
        final memberDoc = _membersCol(groupId).doc(userId);

        // Читаем текущее состояние группы
        final groupSnapshot = await transaction.get(groupDoc);
        if (!groupSnapshot.exists) {
          throw const ServerException(message: 'Группа не найдена');
        }

        final member = GroupMember(
          userId: userId,
          groupId: groupId,
          role: GroupRole.member,
          displayName: displayName,
          joinedAt: DateTime.now(),
        );

        // Создаём member-документ
        transaction.set(memberDoc, GroupMemberDto.toFirestoreMap(member));

        // Обновляем только разрешённые поля в группе
        transaction.update(groupDoc, <String, dynamic>{
          GroupDto.fMembersUids: FieldValue.arrayUnion(<String>[userId]),
          GroupDto.fMembersCount: FieldValue.increment(1),
          GroupDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
        });
      });
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> leaveGroup({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Используем транзакцию для безопасного обновления
      await _firestore.runTransaction((transaction) async {
        final groupDoc = _groupsCol.doc(groupId);
        final memberDoc = _membersCol(groupId).doc(userId);
        final joinRequestDoc = _joinRequestsCol(groupId).doc(userId);

        // Читаем текущее состояние группы
        final groupSnapshot = await transaction.get(groupDoc);
        if (!groupSnapshot.exists) {
          throw const ServerException(message: 'Группа не найдена');
        }

        // Удаляем member-документ
        transaction.delete(memberDoc);

        // Удаляем join_request документ (если существует)
        transaction.delete(joinRequestDoc);

        // Обновляем только разрешённые поля в группе
        transaction.update(groupDoc, <String, dynamic>{
          GroupDto.fMembersUids: FieldValue.arrayRemove(<String>[userId]),
          GroupDto.fMembersCount: FieldValue.increment(-1),
          GroupDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
        });
      });
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Stream<List<GroupMember>> watchGroupMembers(String groupId) {
    return _membersCol(groupId).snapshots().map(
      (snap) => snap.docs
          .map(
            (doc) =>
                GroupMemberDto.fromSnapshot(groupId: groupId, snapshot: doc),
          )
          .toList(growable: false),
    );
  }

  @override
  Future<GroupMember?> getMembership({
    required String groupId,
    required String userId,
  }) async {
    try {
      final snap = await _membersCol(groupId).doc(userId).get();
      if (!snap.exists) return null;
      return GroupMemberDto.fromSnapshot(groupId: groupId, snapshot: snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> setMemberRole({
    required String groupId,
    required String userId,
    required GroupRole role,
  }) async {
    try {
      final batch = _firestore.batch()
        ..update(_membersCol(groupId).doc(userId), <String, dynamic>{
          GroupMemberDto.fRole: role == GroupRole.admin ? 'admin' : 'member',
        })
        ..update(_groupsCol.doc(groupId), <String, dynamic>{
          GroupDto.fAdminsUids: role == GroupRole.admin
              ? FieldValue.arrayUnion(<String>[userId])
              : FieldValue.arrayRemove(<String>[userId]),
          GroupDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
        });
      await batch.commit();
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> requestJoin({
    required String groupId,
    required String userId,
    required String displayName,
  }) async {
    try {
      // Сначала получаем информацию о группе, чтобы узнать владельца
      final groupSnapshot = await _groupsCol.doc(groupId).get();
      if (!groupSnapshot.exists) {
        throw const ServerException(message: 'Группа не найдена');
      }

      final groupData = groupSnapshot.data();
      final groupOwnerId = groupData?[GroupDto.fOwnerId] as String? ?? '';

      // Создаём запрос на вступление с groupOwnerId и displayName
      final request = JoinRequest(
        userId: userId,
        groupId: groupId,
        status: JoinRequestStatus.pending,
        displayName: displayName,
        groupOwnerId: groupOwnerId,
        requestedAt: DateTime.now(),
      );
      await _joinRequestsCol(
        groupId,
      ).doc(userId).set(JoinRequestDto.toFirestoreMap(request));
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> approveJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    try {
      // Получаем информацию о пользователе из запроса
      final requestSnap = await _joinRequestsCol(groupId).doc(userId).get();
      if (!requestSnap.exists) {
        throw const ServerException(message: 'Запрос не найден');
      }

      final requestData = requestSnap.data();
      final displayName =
          requestData?[JoinRequestDto.fDisplayName] as String? ?? '';

      // Просто добавляем пользователя в группу через существующий метод
      await joinGroup(
        groupId: groupId,
        userId: userId,
        displayName: displayName,
      );

      // Затем обновляем статус запроса
      await _joinRequestsCol(groupId).doc(userId).update(<String, dynamic>{
        JoinRequestDto.fStatus: 'approved',
        JoinRequestDto.fRespondedAt: Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> rejectJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    try {
      await _joinRequestsCol(groupId).doc(userId).update(<String, dynamic>{
        JoinRequestDto.fStatus: 'rejected',
        JoinRequestDto.fRespondedAt: Timestamp.fromDate(DateTime.now()),
      });
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<JoinRequest?> getJoinRequest({
    required String groupId,
    required String userId,
  }) async {
    try {
      final snap = await _joinRequestsCol(groupId).doc(userId).get();
      if (!snap.exists) return null;
      return JoinRequestDto.fromSnapshot(groupId: groupId, snapshot: snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Stream<List<JoinRequest>> watchJoinRequests(String groupId) {
    return _joinRequestsCol(groupId)
        .where(JoinRequestDto.fStatus, isEqualTo: 'pending')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (doc) => JoinRequestDto.fromSnapshot(
                  groupId: groupId,
                  snapshot: doc,
                ),
              )
              .whereType<JoinRequest>()
              .toList(growable: false),
        );
  }

  static List<Group> _groupListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(GroupDto.fromSnapshot)
        .whereType<Group>()
        .toList(growable: false);
  }
}
