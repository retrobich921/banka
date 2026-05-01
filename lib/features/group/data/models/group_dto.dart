import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group.dart';

/// DTO-конверсия `Group` ↔ Firestore. Имена полей — `groups/{groupId}` из
/// `PROJECT_PLAN.md`.
abstract final class GroupDto {
  const GroupDto._();

  static const String fName = 'name';
  static const String fDescription = 'description';
  static const String fOwnerId = 'ownerId';
  static const String fCoverUrl = 'coverUrl';
  static const String fIsPublic = 'isPublic';
  static const String fMembersCount = 'membersCount';
  static const String fPostsCount = 'postsCount';
  static const String fTags = 'tags';
  static const String fMembersUids = 'membersUids';
  static const String fCreatedAt = 'createdAt';
  static const String fUpdatedAt = 'updatedAt';

  static Group? fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(snapshot.id, data);
  }

  static Group fromMap(String id, Map<String, dynamic> data) {
    return Group(
      id: id,
      name: (data[fName] as String?) ?? '',
      ownerId: (data[fOwnerId] as String?) ?? '',
      isPublic: (data[fIsPublic] as bool?) ?? false,
      description: (data[fDescription] as String?) ?? '',
      coverUrl: data[fCoverUrl] as String?,
      membersCount: (data[fMembersCount] as num?)?.toInt() ?? 0,
      postsCount: (data[fPostsCount] as num?)?.toInt() ?? 0,
      tags: _stringList(data[fTags]),
      membersUids: _stringList(data[fMembersUids]),
      createdAt: _timestampToDate(data[fCreatedAt]),
      updatedAt: _timestampToDate(data[fUpdatedAt]),
    );
  }

  /// Полный snapshot новой группы — пишем в `set()` при создании.
  static Map<String, dynamic> toFirestoreMap(Group group) {
    return <String, dynamic>{
      fName: group.name,
      fDescription: group.description,
      fOwnerId: group.ownerId,
      if (group.coverUrl != null) fCoverUrl: group.coverUrl,
      fIsPublic: group.isPublic,
      fMembersCount: group.membersCount,
      fPostsCount: group.postsCount,
      fTags: group.tags,
      fMembersUids: group.membersUids,
      if (group.createdAt != null)
        fCreatedAt: Timestamp.fromDate(group.createdAt!),
      if (group.updatedAt != null)
        fUpdatedAt: Timestamp.fromDate(group.updatedAt!),
    };
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List) return const <String>[];
    return raw.whereType<String>().toList(growable: false);
  }

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
