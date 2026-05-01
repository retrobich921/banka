import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group.dart';

/// DTO для документа `groups/{groupId}/members/{userId}`.
abstract final class GroupMemberDto {
  const GroupMemberDto._();

  static const String fRole = 'role';
  static const String fJoinedAt = 'joinedAt';

  /// id документа === userId. groupId передаётся отдельно (parent path).
  static GroupMember fromSnapshot({
    required String groupId,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();
    return GroupMember(
      userId: snapshot.id,
      groupId: groupId,
      role: _roleFromString(data?[fRole] as String?),
      joinedAt: _timestampToDate(data?[fJoinedAt]),
    );
  }

  static Map<String, dynamic> toFirestoreMap(GroupMember member) {
    return <String, dynamic>{
      fRole: _roleToString(member.role),
      if (member.joinedAt != null)
        fJoinedAt: Timestamp.fromDate(member.joinedAt!),
    };
  }

  static GroupRole _roleFromString(String? raw) {
    return switch (raw) {
      'owner' => GroupRole.owner,
      'admin' => GroupRole.admin,
      _ => GroupRole.member,
    };
  }

  static String _roleToString(GroupRole role) => switch (role) {
    GroupRole.owner => 'owner',
    GroupRole.admin => 'admin',
    GroupRole.member => 'member',
  };

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
