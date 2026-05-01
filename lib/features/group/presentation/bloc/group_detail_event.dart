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
  });

  final String groupId;
  final String currentUserId;

  @override
  List<Object?> get props => [groupId, currentUserId];
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
