import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/follow_repository.dart';
import 'follow_user.dart';

@lazySingleton
class UnfollowUser implements UseCase<void, FollowParams> {
  const UnfollowUser(this._repository);

  final FollowRepository _repository;

  @override
  ResultFuture<void> call(FollowParams params) => _repository.unfollow(
    followerId: params.followerId,
    targetUserId: params.targetUserId,
  );
}
