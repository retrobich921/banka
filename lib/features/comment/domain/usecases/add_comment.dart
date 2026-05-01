import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/comment_repository.dart';

@lazySingleton
class AddComment {
  const AddComment(this._repository);

  final CommentRepository _repository;

  ResultFuture<String> call(AddCommentParams params) {
    return _repository.addComment(
      postId: params.postId,
      authorId: params.authorId,
      authorName: params.authorName,
      authorPhotoUrl: params.authorPhotoUrl,
      text: params.text,
    );
  }
}

class AddCommentParams extends Equatable {
  const AddCommentParams({
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorPhotoUrl,
    required this.text,
  });

  final String postId;
  final String authorId;
  final String authorName;
  final String? authorPhotoUrl;
  final String text;

  @override
  List<Object?> get props => [
    postId,
    authorId,
    authorName,
    authorPhotoUrl,
    text,
  ];
}
