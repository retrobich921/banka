import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';
import 'join_group.dart';

/// Запросить вступление в закрытую группу.
@lazySingleton
class RequestJoinGroup implements UseCase<void, GroupMembershipParams> {
  const RequestJoinGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(GroupMembershipParams params) =>
      _repository.requestJoin(
        groupId: params.groupId,
        userId: params.userId,
        displayName: params.displayName,
      );
}
