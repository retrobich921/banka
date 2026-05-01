import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/like_repository.dart';

@lazySingleton
class UnlikePost {
  const UnlikePost(this._repository);

  final LikeRepository _repository;

  ResultFuture<void> call(UnlikePostParams params) {
    return _repository.unlikePost(postId: params.postId, userId: params.userId);
  }
}

class UnlikePostParams extends Equatable {
  const UnlikePostParams({required this.postId, required this.userId});

  final String postId;
  final String userId;

  @override
  List<Object?> get props => [postId, userId];
}
