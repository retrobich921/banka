part of 'search_bloc.dart';

enum SearchStatus { idle, loading, ready, error }

final class SearchState extends Equatable {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.filters = const SearchFilters(),
    this.results = const [],
    this.errorMessage,
  });

  const SearchState.initial() : this();

  final SearchStatus status;
  final String query;
  final SearchFilters filters;
  final List<Post> results;
  final String? errorMessage;

  /// Считаем ввод «значимым», если есть либо ≥ 2 символов в query, либо
  /// хотя бы один фильтр. Иначе показываем подсказку, а не пустую ленту.
  bool get hasInput => query.trim().length >= 2 || filters.hasAny;

  bool get isLoading => status == SearchStatus.loading;
  bool get hasError => status == SearchStatus.error;
  bool get isEmpty =>
      status == SearchStatus.ready && results.isEmpty && hasInput;

  SearchState copyWith({
    SearchStatus? status,
    String? query,
    SearchFilters? filters,
    List<Post>? results,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      filters: filters ?? this.filters,
      results: results ?? this.results,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, query, filters, results, errorMessage];
}
