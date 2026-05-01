import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class WatchFeed {
  const WatchFeed(this._repository);

  final PostRepository _repository;

  ResultStream<List<Post>> call(WatchFeedParams params) {
    return _repository.watchFeed(
      limit: params.limit,
      startAfterId: params.startAfterId,
    );
  }
}

class WatchFeedParams extends Equatable {
  const WatchFeedParams({this.limit = 20, this.startAfterId});

  final int limit;
  final String? startAfterId;

  @override
  List<Object?> get props => [limit, startAfterId];
}
