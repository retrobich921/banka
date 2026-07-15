import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/follow_repository.dart';

@lazySingleton
class GetFollowingIds implements UseCase<List<String>, String> {
  const GetFollowingIds(this._repository);

  final FollowRepository _repository;

  @override
  ResultFuture<List<String>> call(String followerId) =>
      _repository.getFollowingIds(followerId);
}
