part of 'search_bloc.dart';

sealed class SearchEvent extends Equatable {
  const SearchEvent();

  @override
  List<Object?> get props => [];
}

/// Изменился текст в поисковом инпуте — обработчик дебаунсится через
/// `transformer: _debounce(...)`.
final class SearchQueryChanged extends SearchEvent {
  const SearchQueryChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// Изменился набор фильтров (rarity range / brandId / groupId) —
/// сразу перезапрашиваем результат с текущим query.
final class SearchFiltersChanged extends SearchEvent {
  const SearchFiltersChanged(this.filters);

  final SearchFilters filters;

  @override
  List<Object?> get props => [filters];
}

/// Полный сброс: пустой query, дефолтные фильтры, очищенные результаты.
final class SearchResetRequested extends SearchEvent {
  const SearchResetRequested();
}
