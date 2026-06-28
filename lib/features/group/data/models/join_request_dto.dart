import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/group.dart';

/// DTO-конверсия `JoinRequest` ↔ Firestore.
abstract final class JoinRequestDto {
  const JoinRequestDto._();

  static const String fStatus = 'status';
  static const String fDisplayName = 'displayName';
  static const String fGroupOwnerId = 'groupOwnerId';
  static const String fRequestedAt = 'requestedAt';
  static const String fRespondedAt = 'respondedAt';

  static JoinRequest? fromSnapshot({
    required String groupId,
    required DocumentSnapshot<Map<String, dynamic>> snapshot,
  }) {
    final data = snapshot.data();
    if (data == null) return null;
    return fromMap(groupId: groupId, userId: snapshot.id, data: data);
  }

  static JoinRequest fromMap({
    required String groupId,
    required String userId,
    required Map<String, dynamic> data,
  }) {
    return JoinRequest(
      userId: userId,
      groupId: groupId,
      status: _parseStatus(data[fStatus]),
      displayName: (data[fDisplayName] as String?) ?? '',
      groupOwnerId: (data[fGroupOwnerId] as String?) ?? '',
      requestedAt: _timestampToDate(data[fRequestedAt]),
      respondedAt: _timestampToDate(data[fRespondedAt]),
    );
  }

  static Map<String, dynamic> toFirestoreMap(JoinRequest request) {
    return <String, dynamic>{
      fStatus: _statusToString(request.status),
      fDisplayName: request.displayName,
      fGroupOwnerId: request.groupOwnerId,
      if (request.requestedAt != null)
        fRequestedAt: Timestamp.fromDate(request.requestedAt!),
      if (request.respondedAt != null)
        fRespondedAt: Timestamp.fromDate(request.respondedAt!),
    };
  }

  static JoinRequestStatus _parseStatus(Object? raw) {
    if (raw is! String) return JoinRequestStatus.pending;
    return switch (raw) {
      'approved' => JoinRequestStatus.approved,
      'rejected' => JoinRequestStatus.rejected,
      _ => JoinRequestStatus.pending,
    };
  }

  static String _statusToString(JoinRequestStatus status) => switch (status) {
    JoinRequestStatus.pending => 'pending',
    JoinRequestStatus.approved => 'approved',
    JoinRequestStatus.rejected => 'rejected',
  };

  static DateTime? _timestampToDate(Object? raw) {
    if (raw == null) return null;
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return null;
  }
}
