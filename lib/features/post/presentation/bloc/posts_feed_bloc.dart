import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/fetch_feed_page.dart';
import '../../domain/usecases/watch_author_feed.dart';
import '../../domain/usecases/watch_brand_feed.dart';
import '../../domain/usecases/watch_feed.dart';
import '../../domain/usecases/watch_group_feed.dart';

part 'posts_feed_event.dart';
part 'posts_feed_state.dart';

/// Управляет лентой постов (общая / группа / бренд / автор).
///
/// Пагинация — курсорная:
/// - Первая страница (`_pageSize`) живёт в realtime через `Watch*Feed` —
///   новые посты и счётчики лайков/комментов обновляются мгновенно.
/// - `PostsFeedLoadMoreRequested` дочитывает следующую страницу разовым
///   `FetchFeedPage` (startAfter последнего поста) и дописывает её в конец —
///   уже загруженные посты не перечитываются, поэтому подгрузка быстрая.
@injectable
class PostsFeedBloc extends Bloc<PostsFeedEvent, PostsFeedState> {
  PostsFeedBloc(
    this._watchFeed,
    this._watchGroupFeed,
    this._watchBrandFeed,
    this._watchAuthorFeed,
    this._fetchFeedPage,
  ) : super(const PostsFeedState.initial()) {
    on<PostsFeedSubscribeRequested>(_onSubscribe);
    on<PostsFeedLoadMoreRequested>(_onLoadMore);
    on<_PostsFeedReceived>(_onReceived);
    on<PostsFeedResetRequested>(_onReset);
  }

  final WatchFeed _watchFeed;
  final WatchGroupFeed _watchGroupFeed;
  final WatchBrandFeed _watchBrandFeed;
  final WatchAuthorFeed _watchAuthorFeed;
  final FetchFeedPage _fetchFeedPage;

  static const int _pageSize = 20;

  /// Первая (realtime) страница и дочитанные скроллом страницы.
  List<Post> _firstPage = const [];
  List<Post> _more = const [];
  bool _reachedEnd = false;

  StreamSubscription<Either<Failure, List<Post>>>? _sub;
  PostsFeedScope? _currentScope;

  Stream<Either<Failure, List<Post>>> _streamFor(PostsFeedScope scope) {
    if (scope.brandId != null) {
      return _watchBrandFeed(
        WatchBrandFeedParams(brandId: scope.brandId!, limit: _pageSize),
      );
    }
    if (scope.groupId != null) {
      return _watchGroupFeed(
        WatchGroupFeedParams(groupId: scope.groupId!, limit: _pageSize),
      );
    }
    if (scope.authorId != null) {
      return _watchAuthorFeed(
        WatchAuthorFeedParams(authorId: scope.authorId!, limit: _pageSize),
      );
    }
    return _watchFeed(const WatchFeedParams(limit: _pageSize));
  }

  /// Склейка realtime-первой страницы и дочитанных страниц без дублей.
  List<Post> _combined() {
    final ids = _firstPage.map((p) => p.id).toSet();
    return [..._firstPage, ..._more.where((p) => !ids.contains(p.id))];
  }

  Future<void> _onSubscribe(
    PostsFeedSubscribeRequested event,
    Emitter<PostsFeedState> emit,
  ) async {
    if (_currentScope == event.scope && _sub != null) return;
    _currentScope = event.scope;
    _firstPage = const [];
    _more = const [];
    _reachedEnd = false;

    emit(
      state.copyWith(
        status: PostsFeedStatus.loading,
        scope: event.scope,
        posts: const [],
        clearError: true,
        isLoadingMore: false,
        hasReachedEnd: false,
      ),
    );

    await _sub?.cancel();
    _sub = _streamFor(event.scope).listen((r) => add(_PostsFeedReceived(r)));
  }

  Future<void> _onLoadMore(
    PostsFeedLoadMoreRequested event,
    Emitter<PostsFeedState> emit,
  ) async {
    final scope = _currentScope;
    if (scope == null || state.isLoadingMore || _reachedEnd) return;
    final current = state.posts;
    if (current.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await _fetchFeedPage(
      FetchFeedPageParams(
        groupId: scope.groupId,
        brandId: scope.brandId,
        authorId: scope.authorId,
        startAfterId: current.last.id,
        limit: _pageSize,
      ),
    );

    result.fold(
      // Тихо снимаем спиннер — список остаётся, пользователь может повторить.
      (_) => emit(state.copyWith(isLoadingMore: false)),
      (page) {
        if (page.length < _pageSize) _reachedEnd = true;
        final existing = current.map((p) => p.id).toSet();
        _more = [..._more, ...page.where((p) => !existing.contains(p.id))];
        emit(
          state.copyWith(
            posts: _combined(),
            isLoadingMore: false,
            hasReachedEnd: _reachedEnd,
          ),
        );
      },
    );
  }

  void _onReceived(_PostsFeedReceived event, Emitter<PostsFeedState> emit) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: PostsFeedStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить ленту',
        ),
      ),
      (posts) {
        _firstPage = posts;
        // Если первая страница неполная — постов всего меньше страницы,
        // дочитывать нечего.
        if (posts.length < _pageSize && _more.isEmpty) _reachedEnd = true;
        emit(
          state.copyWith(
            status: PostsFeedStatus.ready,
            posts: _combined(),
            clearError: true,
            hasReachedEnd: _reachedEnd,
          ),
        );
      },
    );
  }

  Future<void> _onReset(
    PostsFeedResetRequested event,
    Emitter<PostsFeedState> emit,
  ) async {
    await _sub?.cancel();
    _sub = null;
    _currentScope = null;
    _firstPage = const [];
    _more = const [];
    _reachedEnd = false;
    emit(const PostsFeedState.initial());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
