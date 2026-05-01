import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/group.dart';
import '../models/group_dto.dart';
import '../models/group_member_dto.dart';

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

  Future<void> joinGroup({required String groupId, required String userId});

  Future<void> leaveGroup({required String groupId, required String userId});

  Stream<List<GroupMember>> watchGroupMembers(String groupId);

  Future<GroupMember?> getMembership({
    required String groupId,
    required String userId,
  });
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

  CollectionReference<Map<String, dynamic>> get _groupsCol =>
      _firestore.collection(_groups);

  CollectionReference<Map<String, dynamic>> _membersCol(String groupId) =>
      _groupsCol.doc(groupId).collection(_members);

  @override
  Future<Group> createGroup({
    required String ownerId,
    required String name,
    required String description,
    required bool isPublic,
    required List<String> tags,
    String? coverUrl,
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
        createdAt: now,
        updatedAt: now,
      );
      final ownerMember = GroupMember(
        userId: ownerId,
        groupId: doc.id,
        role: GroupRole.owner,
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
    Query<Map<String, dynamic>> query = _groupsCol
        .where(GroupDto.fIsPublic, isEqualTo: true)
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
  }) async {
    try {
      final groupDoc = _groupsCol.doc(groupId);
      final memberDoc = _membersCol(groupId).doc(userId);
      final member = GroupMember(
        userId: userId,
        groupId: groupId,
        role: GroupRole.member,
        joinedAt: DateTime.now(),
      );
      final batch = _firestore.batch()
        ..set(memberDoc, GroupMemberDto.toFirestoreMap(member))
        ..update(groupDoc, <String, dynamic>{
          GroupDto.fMembersUids: FieldValue.arrayUnion(<String>[userId]),
          GroupDto.fMembersCount: FieldValue.increment(1),
          GroupDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
        });
      await batch.commit();
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
      final groupDoc = _groupsCol.doc(groupId);
      final memberDoc = _membersCol(groupId).doc(userId);
      final batch = _firestore.batch()
        ..delete(memberDoc)
        ..update(groupDoc, <String, dynamic>{
          GroupDto.fMembersUids: FieldValue.arrayRemove(<String>[userId]),
          GroupDto.fMembersCount: FieldValue.increment(-1),
          GroupDto.fUpdatedAt: Timestamp.fromDate(DateTime.now()),
        });
      await batch.commit();
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

  static List<Group> _groupListFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(GroupDto.fromSnapshot)
        .whereType<Group>()
        .toList(growable: false);
  }
}
