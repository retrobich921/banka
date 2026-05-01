part of 'groups_list_bloc.dart';

enum GroupsListStatus { initial, loading, ready, creating, created, error }

final class GroupsListState extends Equatable {
  const GroupsListState({
    this.status = GroupsListStatus.initial,
    this.myGroups = const <Group>[],
    this.publicGroups = const <Group>[],
    this.errorMessage,
    this.createdGroupId,
  });

  const GroupsListState.initial() : this();

  final GroupsListStatus status;
  final List<Group> myGroups;
  final List<Group> publicGroups;
  final String? errorMessage;
  final String? createdGroupId;

  bool get isCreating => status == GroupsListStatus.creating;
  bool get isLoading => status == GroupsListStatus.loading;

  GroupsListState copyWith({
    GroupsListStatus? status,
    List<Group>? myGroups,
    List<Group>? publicGroups,
    String? errorMessage,
    String? createdGroupId,
    bool clearError = false,
    bool clearCreatedId = false,
  }) {
    return GroupsListState(
      status: status ?? this.status,
      myGroups: myGroups ?? this.myGroups,
      publicGroups: publicGroups ?? this.publicGroups,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      createdGroupId: clearCreatedId
          ? null
          : (createdGroupId ?? this.createdGroupId),
    );
  }

  @override
  List<Object?> get props => [
    status,
    myGroups,
    publicGroups,
    errorMessage,
    createdGroupId,
  ];
}
