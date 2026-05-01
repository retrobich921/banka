import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../../../post/domain/entities/post.dart';
import '../../../post/domain/repositories/post_repository.dart';
import '../entities/search_filters.dart';

/// Usecase интерактивного поиска по `searchKeywords` + опциональным
/// фильтрам. Делегирует в `PostRepository.searchPosts`.
@lazySingleton
class SearchPosts {
  const SearchPosts(this._repository);

  final PostRepository _repository;

  ResultFuture<List<Post>> call(SearchPostsParams params) {
    return _repository.searchPosts(
      query: params.query,
      rarityMin: params.filters.rarityMin,
      rarityMax: params.filters.rarityMax,
      brandId: params.filters.brandId,
      groupId: params.filters.groupId,
    );
  }
}

class SearchPostsParams extends Equatable {
  const SearchPostsParams({this.query, this.filters = const SearchFilters()});

  final String? query;
  final SearchFilters filters;

  @override
  List<Object?> get props => [query, filters];
}
