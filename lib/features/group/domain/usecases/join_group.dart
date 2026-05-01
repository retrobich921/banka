import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class JoinGroup implements UseCase<void, GroupMembershipParams> {
  const JoinGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(GroupMembershipParams params) =>
      _repository.joinGroup(groupId: params.groupId, userId: params.userId);
}

class GroupMembershipParams extends Equatable {
  const GroupMembershipParams({required this.groupId, required this.userId});

  final String groupId;
  final String userId;

  @override
  List<Object?> get props => [groupId, userId];
}
