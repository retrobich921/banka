import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Разовая загрузка следующей страницы ленты (курсорная пагинация при
/// скролле). В отличие от `Watch*Feed`, не realtime — отдаёт ровно одну
/// страницу постов после `startAfterId`.
@lazySingleton
class FetchFeedPage {
  const FetchFeedPage(this._repository);

  final PostRepository _repository;

  ResultFuture<List<Post>> call(FetchFeedPageParams params) {
    return _repository.getFeedPage(
      groupId: params.groupId,
      brandId: params.brandId,
      authorId: params.authorId,
      startAfterId: params.startAfterId,
      limit: params.limit,
    );
  }
}

class FetchFeedPageParams extends Equatable {
  const FetchFeedPageParams({
    this.groupId,
    this.brandId,
    this.authorId,
    this.startAfterId,
    this.limit = 20,
  });

  final String? groupId;
  final String? brandId;
  final String? authorId;
  final String? startAfterId;
  final int limit;

  @override
  List<Object?> get props => [groupId, brandId, authorId, startAfterId, limit];
}
