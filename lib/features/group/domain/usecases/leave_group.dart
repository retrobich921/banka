import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';
import 'join_group.dart' show GroupMembershipParams;

@lazySingleton
class LeaveGroup implements UseCase<void, GroupMembershipParams> {
  const LeaveGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(GroupMembershipParams params) =>
      _repository.leaveGroup(groupId: params.groupId, userId: params.userId);
}
