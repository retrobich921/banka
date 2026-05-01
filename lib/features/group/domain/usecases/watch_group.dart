import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class WatchGroup implements StreamResultUseCase<Group?, String> {
  const WatchGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultStream<Group?> call(String groupId) => _repository.watchGroup(groupId);
}
