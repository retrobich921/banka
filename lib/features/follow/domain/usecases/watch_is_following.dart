import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/follow_repository.dart';
import 'follow_user.dart';

@lazySingleton
class WatchIsFollowing implements StreamResultUseCase<bool, FollowParams> {
  const WatchIsFollowing(this._repository);

  final FollowRepository _repository;

  @override
  ResultStream<bool> call(FollowParams params) => _repository.watchIsFollowing(
    followerId: params.followerId,
    targetUserId: params.targetUserId,
  );
}
