import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class WatchPost {
  const WatchPost(this._repository);

  final PostRepository _repository;

  ResultStream<Post?> call(String postId) => _repository.watchPost(postId);
}
