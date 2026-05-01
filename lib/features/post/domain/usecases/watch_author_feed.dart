import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class WatchAuthorFeed {
  const WatchAuthorFeed(this._repository);

  final PostRepository _repository;

  ResultStream<List<Post>> call(WatchAuthorFeedParams params) {
    return _repository.watchAuthorFeed(
      authorId: params.authorId,
      limit: params.limit,
      startAfterId: params.startAfterId,
    );
  }
}

class WatchAuthorFeedParams extends Equatable {
  const WatchAuthorFeedParams({
    required this.authorId,
    this.limit = 20,
    this.startAfterId,
  });

  final String authorId;
  final int limit;
  final String? startAfterId;

  @override
  List<Object?> get props => [authorId, limit, startAfterId];
}
