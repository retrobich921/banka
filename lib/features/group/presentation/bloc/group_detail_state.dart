part of 'group_detail_bloc.dart';

enum GroupDetailStatus {
  initial,
  loading,
  ready,
  mutating,
  deleted,
  notFound,
  error,
}

final class GroupDetailState extends Equatable {
  const GroupDetailState({
    this.status = GroupDetailStatus.initial,
    this.group,
    this.members = const <GroupMember>[],
    this.currentUserId,
    this.currentUserDisplayName,
    this.errorMessage,
    this.joinRequest,
  });

  const GroupDetailState.initial() : this();

  final GroupDetailStatus status;
  final Group? group;
  final List<GroupMember> members;
  final String? currentUserId;
  final String? currentUserDisplayName;
  final String? errorMessage;
  final JoinRequest? joinRequest;

  bool get isOwner =>
      group != null && currentUserId != null && group!.ownerId == currentUserId;

  bool get isMember {
    if (group == null || currentUserId == null) return false;
    return group!.membersUids.contains(currentUserId);
  }

  bool get hasPendingRequest =>
      joinRequest != null && joinRequest!.status == JoinRequestStatus.pending;

  bool get isMutating => status == GroupDetailStatus.mutating;

  GroupDetailState copyWith({
    GroupDetailStatus? status,
    Group? group,
    List<GroupMember>? members,
    String? currentUserId,
    String? currentUserDisplayName,
    String? errorMessage,
    JoinRequest? joinRequest,
    bool clearGroup = false,
    bool clearError = false,
    bool clearJoinRequest = false,
  }) {
    return GroupDetailState(
      status: status ?? this.status,
      group: clearGroup ? null : (group ?? this.group),
      members: members ?? this.members,
      currentUserId: currentUserId ?? this.currentUserId,
      currentUserDisplayName: currentUserDisplayName ?? this.currentUserDisplayName,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      joinRequest: clearJoinRequest ? null : (joinRequest ?? this.joinRequest),
    );
  }

  @override
  List<Object?> get props => [
    status,
    group,
    members,
    currentUserId,
    currentUserDisplayName,
    errorMessage,
    joinRequest,
  ];
}
