import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/like_repository.dart';

@lazySingleton
class WatchHasLiked {
  const WatchHasLiked(this._repository);

  final LikeRepository _repository;

  ResultStream<bool> call(WatchHasLikedParams params) {
    return _repository.watchHasLiked(
      postId: params.postId,
      userId: params.userId,
    );
  }
}

class WatchHasLikedParams extends Equatable {
  const WatchHasLikedParams({required this.postId, required this.userId});

  final String postId;
  final String userId;

  @override
  List<Object?> get props => [postId, userId];
}
