import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/follow_repository.dart';

@lazySingleton
class FollowUser implements UseCase<void, FollowParams> {
  const FollowUser(this._repository);

  final FollowRepository _repository;

  @override
  ResultFuture<void> call(FollowParams params) => _repository.follow(
    followerId: params.followerId,
    targetUserId: params.targetUserId,
  );
}

final class FollowParams extends Equatable {
  const FollowParams({required this.followerId, required this.targetUserId});

  final String followerId;
  final String targetUserId;

  @override
  List<Object?> get props => [followerId, targetUserId];
}
