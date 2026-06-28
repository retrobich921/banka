import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class RejectJoinRequest implements UseCase<void, RejectJoinRequestParams> {
  const RejectJoinRequest(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(RejectJoinRequestParams params) => _repository
      .rejectJoinRequest(groupId: params.groupId, userId: params.userId);
}

class RejectJoinRequestParams extends Equatable {
  const RejectJoinRequestParams({required this.groupId, required this.userId});

  final String groupId;
  final String userId;

  @override
  List<Object?> get props => [groupId, userId];
}
