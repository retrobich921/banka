import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

/// Получить запрос на вступление конкретного пользователя в группу.
@lazySingleton
class GetJoinRequest {
  const GetJoinRequest(this._repository);

  final GroupRepository _repository;

  Future<Either<Failure, JoinRequest?>> call({
    required String groupId,
    required String userId,
  }) {
    return _repository.getJoinRequest(groupId: groupId, userId: userId);
  }
}
