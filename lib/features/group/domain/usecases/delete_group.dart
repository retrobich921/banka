import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class DeleteGroup implements UseCase<void, String> {
  const DeleteGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(String groupId) => _repository.deleteGroup(groupId);
}
