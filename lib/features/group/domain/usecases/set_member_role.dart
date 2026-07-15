import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

/// Назначить или снять админа группы. Доступно только владельцу
/// (enforced в Security Rules).
@lazySingleton
class SetMemberRole implements UseCase<void, SetMemberRoleParams> {
  const SetMemberRole(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(SetMemberRoleParams params) =>
      _repository.setMemberRole(
        groupId: params.groupId,
        userId: params.userId,
        role: params.role,
      );
}

final class SetMemberRoleParams extends Equatable {
  const SetMemberRoleParams({
    required this.groupId,
    required this.userId,
    required this.role,
  });

  final String groupId;
  final String userId;
  final GroupRole role;

  @override
  List<Object?> get props => [groupId, userId, role];
}
