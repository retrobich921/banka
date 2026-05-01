import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/like_repository.dart';

@lazySingleton
class LikePost {
  const LikePost(this._repository);

  final LikeRepository _repository;

  ResultFuture<void> call(LikePostParams params) {
    return _repository.likePost(
      postId: params.postId,
      userId: params.userId,
      userName: params.userName,
      userPhotoUrl: params.userPhotoUrl,
    );
  }
}

class LikePostParams extends Equatable {
  const LikePostParams({
    required this.postId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
  });

  final String postId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;

  @override
  List<Object?> get props => [postId, userId, userName, userPhotoUrl];
}
