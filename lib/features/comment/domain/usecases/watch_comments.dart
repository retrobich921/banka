import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/comment.dart';
import '../repositories/comment_repository.dart';

@lazySingleton
class WatchComments {
  const WatchComments(this._repository);

  final CommentRepository _repository;

  ResultStream<List<Comment>> call(String postId) {
    return _repository.watchComments(postId);
  }
}
