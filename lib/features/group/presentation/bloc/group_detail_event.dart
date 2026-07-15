part of 'group_detail_bloc.dart';

sealed class GroupDetailEvent extends Equatable {
  const GroupDetailEvent();

  @override
  List<Object?> get props => const [];
}

final class GroupDetailSubscribeRequested extends GroupDetailEvent {
  const GroupDetailSubscribeRequested({
    required this.groupId,
    required this.currentUserId,
    this.currentUserDisplayName,
  });

  final String groupId;
  final String currentUserId;
  final String? currentUserDisplayName;

  @override
  List<Object?> get props => [groupId, currentUserId, currentUserDisplayName];
}

final class GroupDetailJoinRequested extends GroupDetailEvent {
  const GroupDetailJoinRequested();
}

final class GroupDetailLeaveRequested extends GroupDetailEvent {
  const GroupDetailLeaveRequested();
}

final class GroupDetailDeleteRequested extends GroupDetailEvent {
  const GroupDetailDeleteRequested();
}

/// Владелец назначает/снимает админа у участника [userId].
final class GroupDetailSetRoleRequested extends GroupDetailEvent {
  const GroupDetailSetRoleRequested({required this.userId, required this.role});

  final String userId;
  final GroupRole role;

  @override
  List<Object?> get props => [userId, role];
}

final class GroupDetailResetRequested extends GroupDetailEvent {
  const GroupDetailResetRequested();
}

final class _GroupDetailGroupReceived extends GroupDetailEvent {
  const _GroupDetailGroupReceived(this.result);
  final Either<Failure, Group?> result;
  @override
  List<Object?> get props => [result];
}

final class _GroupDetailMembersReceived extends GroupDetailEvent {
  const _GroupDetailMembersReceived(this.result);
  final Either<Failure, List<GroupMember>> result;
  @override
  List<Object?> get props => [result];
}
