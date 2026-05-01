import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class WatchBrandFeed {
  const WatchBrandFeed(this._repository);

  final PostRepository _repository;

  ResultStream<List<Post>> call(WatchBrandFeedParams params) {
    return _repository.watchBrandFeed(
      brandId: params.brandId,
      limit: params.limit,
      startAfterId: params.startAfterId,
    );
  }
}

class WatchBrandFeedParams extends Equatable {
  const WatchBrandFeedParams({
    required this.brandId,
    this.limit = 20,
    this.startAfterId,
  });

  final String brandId;
  final int limit;
  final String? startAfterId;

  @override
  List<Object?> get props => [brandId, limit, startAfterId];
}
