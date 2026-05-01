import 'package:banka/core/error/failures.dart';
import 'package:banka/features/post/domain/entities/post.dart';
import 'package:banka/features/search/domain/entities/search_filters.dart';
import 'package:banka/features/search/domain/usecases/search_posts.dart';
import 'package:banka/features/search/presentation/bloc/search_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSearchPosts extends Mock implements SearchPosts {}

void main() {
  late _MockSearchPosts searchPosts;

  final fixture = Post(
    id: 'p1',
    authorId: 'u1',
    authorName: 'Albert',
    drinkName: 'Monster Energy',
    rarity: 7,
    createdAt: DateTime(2025, 5, 1),
  );

  setUpAll(() {
    registerFallbackValue(const SearchPostsParams());
  });

  setUp(() {
    searchPosts = _MockSearchPosts();
  });

  SearchBloc buildBloc() => SearchBloc(searchPosts);

  group('SearchQueryChanged', () {
    blocTest<SearchBloc, SearchState>(
      'meaningful query → loading → ready (с дебаунсом 300 ms)',
      setUp: () {
        when(
          () => searchPosts(any()),
        ).thenAnswer((_) async => Right<Failure, List<Post>>([fixture]));
      },
      build: buildBloc,
      act: (b) => b.add(const SearchQueryChanged('monster')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.loading)
            .having((s) => s.query, 'query', 'monster'),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.ready)
            .having((s) => s.results.length, 'count', 1)
            .having((s) => s.results.first.id, 'id', 'p1'),
      ],
      verify: (_) {
        verify(() => searchPosts(any())).called(1);
      },
    );

    blocTest<SearchBloc, SearchState>(
      'короткий query (<2 символов) ничего не запрашивает и остаётся idle',
      build: buildBloc,
      act: (b) => b.add(const SearchQueryChanged('a')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.idle)
            .having((s) => s.query, 'query', 'a')
            .having((s) => s.results, 'results', isEmpty),
      ],
      verify: (_) {
        verifyNever(() => searchPosts(any()));
      },
    );

    blocTest<SearchBloc, SearchState>(
      'Left(Failure) → status=error + errorMessage',
      setUp: () {
        when(() => searchPosts(any())).thenAnswer(
          (_) async =>
              const Left<Failure, List<Post>>(ServerFailure(message: 'boom')),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const SearchQueryChanged('monster')),
      wait: const Duration(milliseconds: 350),
      expect: () => [
        isA<SearchState>().having(
          (s) => s.status,
          'status',
          SearchStatus.loading,
        ),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.error)
            .having((s) => s.errorMessage, 'msg', 'boom'),
      ],
    );
  });

  group('SearchFiltersChanged', () {
    blocTest<SearchBloc, SearchState>(
      'фильтры без query всё равно триггерят поиск (browse-режим)',
      setUp: () {
        when(
          () => searchPosts(any()),
        ).thenAnswer((_) async => Right<Failure, List<Post>>([fixture]));
      },
      build: buildBloc,
      act: (b) => b.add(
        const SearchFiltersChanged(SearchFilters(rarityMin: 5, rarityMax: 9)),
      ),
      expect: () => [
        isA<SearchState>().having(
          (s) => s.status,
          'status',
          SearchStatus.loading,
        ),
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.ready)
            .having((s) => s.filters.rarityMin, 'rarityMin', 5)
            .having((s) => s.filters.rarityMax, 'rarityMax', 9),
      ],
    );

    blocTest<SearchBloc, SearchState>(
      'пустые фильтры + пустой query → idle, без вызова usecase',
      build: buildBloc,
      act: (b) => b.add(const SearchFiltersChanged(SearchFilters.empty())),
      expect: () => [
        isA<SearchState>().having((s) => s.status, 'status', SearchStatus.idle),
      ],
      verify: (_) {
        verifyNever(() => searchPosts(any()));
      },
    );
  });

  group('SearchResetRequested', () {
    blocTest<SearchBloc, SearchState>(
      'сбрасывает state в initial',
      setUp: () {
        when(
          () => searchPosts(any()),
        ).thenAnswer((_) async => Right<Failure, List<Post>>([fixture]));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const SearchFiltersChanged(SearchFilters(rarityMin: 5)));
        await Future<void>.delayed(const Duration(milliseconds: 50));
        b.add(const SearchResetRequested());
      },
      skip: 2,
      expect: () => [
        isA<SearchState>()
            .having((s) => s.status, 'status', SearchStatus.idle)
            .having((s) => s.query, 'query', '')
            .having((s) => s.filters.hasAny, 'no filters', isFalse)
            .having((s) => s.results, 'results', isEmpty),
      ],
    );
  });
}
