import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class ApproveJoinRequest implements UseCase<void, ApproveJoinRequestParams> {
  const ApproveJoinRequest(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(ApproveJoinRequestParams params) => _repository
      .approveJoinRequest(groupId: params.groupId, userId: params.userId);
}

class ApproveJoinRequestParams extends Equatable {
  const ApproveJoinRequestParams({required this.groupId, required this.userId});

  final String groupId;
  final String userId;

  @override
  List<Object?> get props => [groupId, userId];
}
