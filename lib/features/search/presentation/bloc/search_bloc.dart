import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../post/domain/entities/post.dart';
import '../../domain/entities/search_filters.dart';
import '../../domain/usecases/search_posts.dart';

part 'search_event.dart';
part 'search_state.dart';

/// BLoC поиска постов.
///
/// - `SearchQueryChanged` дебаунсится 300 ms — печатание не плодит
///   запросов в Firestore.
/// - `SearchFiltersChanged` срабатывает мгновенно: смена чекбокса /
///   слайдера должна отдавать ответ сразу.
/// - Если нет «значимого» ввода (`<2` символов и ноль фильтров),
///   возвращаемся в `idle` с пустым списком — экран покажет подсказку.
@injectable
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  SearchBloc(this._searchPosts) : super(const SearchState.initial()) {
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounceRestartable(_debounceDuration),
    );
    on<SearchFiltersChanged>(_onFiltersChanged);
    on<SearchResetRequested>(_onReset);
  }

  final SearchPosts _searchPosts;

  static const Duration _debounceDuration = Duration(milliseconds: 300);

  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    await _runSearch(query: event.query, filters: state.filters, emit: emit);
  }

  Future<void> _onFiltersChanged(
    SearchFiltersChanged event,
    Emitter<SearchState> emit,
  ) async {
    await _runSearch(query: state.query, filters: event.filters, emit: emit);
  }

  Future<void> _runSearch({
    required String query,
    required SearchFilters filters,
    required Emitter<SearchState> emit,
  }) async {
    final next = state.copyWith(
      query: query,
      filters: filters,
      clearError: true,
    );
    final hasMeaningfulInput = next.hasInput;

    if (!hasMeaningfulInput) {
      emit(next.copyWith(status: SearchStatus.idle, results: const <Post>[]));
      return;
    }

    emit(next.copyWith(status: SearchStatus.loading));

    final result = await _searchPosts(
      SearchPostsParams(query: query.trim(), filters: filters),
    );
    if (emit.isDone) return;

    result.fold(
      (failure) => emit(
        next.copyWith(
          status: SearchStatus.error,
          errorMessage: failure.message ?? 'Не удалось выполнить поиск',
        ),
      ),
      (posts) => emit(
        next.copyWith(
          status: SearchStatus.ready,
          results: posts,
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _onReset(
    SearchResetRequested event,
    Emitter<SearchState> emit,
  ) async {
    emit(const SearchState.initial());
  }

  /// Дебаунс + restart — пока пользователь печатает, в работе максимум
  /// один запрос; новое нажатие отменяет предыдущее.
  static EventTransformer<E> _debounceRestartable<E>(Duration duration) {
    return (events, mapper) => events.debounce(duration).switchMap(mapper);
  }
}
