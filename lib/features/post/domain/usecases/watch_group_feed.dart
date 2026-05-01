import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class WatchGroupFeed {
  const WatchGroupFeed(this._repository);

  final PostRepository _repository;

  ResultStream<List<Post>> call(WatchGroupFeedParams params) {
    return _repository.watchGroupFeed(
      groupId: params.groupId,
      limit: params.limit,
      startAfterId: params.startAfterId,
    );
  }
}

class WatchGroupFeedParams extends Equatable {
  const WatchGroupFeedParams({
    required this.groupId,
    this.limit = 20,
    this.startAfterId,
  });

  final String groupId;
  final int limit;
  final String? startAfterId;

  @override
  List<Object?> get props => [groupId, limit, startAfterId];
}
