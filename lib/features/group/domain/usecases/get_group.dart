import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class GetGroup implements UseCase<Group?, String> {
  const GetGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<Group?> call(String groupId) => _repository.getGroup(groupId);
}
