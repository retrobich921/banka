import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/like.dart';
import '../repositories/like_repository.dart';

@lazySingleton
class WatchLikers {
  const WatchLikers(this._repository);

  final LikeRepository _repository;

  ResultStream<List<Like>> call(String postId) =>
      _repository.watchLikers(postId);
}
