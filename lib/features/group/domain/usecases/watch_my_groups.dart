import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class WatchMyGroups implements StreamResultUseCase<List<Group>, String> {
  const WatchMyGroups(this._repository);

  final GroupRepository _repository;

  @override
  ResultStream<List<Group>> call(String userId) =>
      _repository.watchMyGroups(userId);
}
