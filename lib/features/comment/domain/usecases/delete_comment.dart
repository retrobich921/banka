import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/comment_repository.dart';

@lazySingleton
class DeleteComment {
  const DeleteComment(this._repository);

  final CommentRepository _repository;

  ResultFuture<void> call(DeleteCommentParams params) {
    return _repository.deleteComment(
      postId: params.postId,
      commentId: params.commentId,
    );
  }
}

class DeleteCommentParams extends Equatable {
  const DeleteCommentParams({required this.postId, required this.commentId});

  final String postId;
  final String commentId;

  @override
  List<Object?> get props => [postId, commentId];
}
