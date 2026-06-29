import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../entities/post_ranking.dart';
import '../repositories/post_repository.dart';

/// Топ постов для раздела «Топы» (одноразовый запрос, без realtime).
@lazySingleton
class TopPosts {
  const TopPosts(this._repository);

  final PostRepository _repository;

  ResultFuture<List<Post>> call(TopPostsParams params) =>
      _repository.topPosts(ranking: params.ranking, limit: params.limit);
}

class TopPostsParams extends Equatable {
  const TopPostsParams({required this.ranking, this.limit = 50});

  final PostRanking ranking;
  final int limit;

  @override
  List<Object?> get props => [ranking, limit];
}
