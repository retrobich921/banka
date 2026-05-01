import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/watch_feed.dart';
import '../../domain/usecases/watch_group_feed.dart';

part 'posts_feed_event.dart';
part 'posts_feed_state.dart';

/// Управляет лентой постов (общая или скоупом группы).
///
/// Поведение:
/// - При `PostsFeedSubscribeRequested(scope)` отписываемся от прошлой
///   подписки и поднимаем новую через нужный usecase.
/// - Поток постов прилетает уже отсортированный по `createdAt desc` из
///   репозитория, тут только перекладываем `Either<Failure, List<Post>>`
///   в стейт.
/// - Пагинация (`startAfterId`) пока не используется в UI — при
///   достижении конца вернёмся в Sprint 12 / polish.
@injectable
class PostsFeedBloc extends Bloc<PostsFeedEvent, PostsFeedState> {
  PostsFeedBloc(this._watchFeed, this._watchGroupFeed)
    : super(const PostsFeedState.initial()) {
    on<PostsFeedSubscribeRequested>(_onSubscribe);
    on<_PostsFeedReceived>(_onReceived);
    on<PostsFeedResetRequested>(_onReset);
  }

  final WatchFeed _watchFeed;
  final WatchGroupFeed _watchGroupFeed;

  StreamSubscription<Either<Failure, List<Post>>>? _sub;
  PostsFeedScope? _currentScope;

  Future<void> _onSubscribe(
    PostsFeedSubscribeRequested event,
    Emitter<PostsFeedState> emit,
  ) async {
    if (_currentScope == event.scope && _sub != null) return;
    _currentScope = event.scope;

    emit(
      state.copyWith(
        status: PostsFeedStatus.loading,
        scope: event.scope,
        clearError: true,
      ),
    );

    await _sub?.cancel();
    final stream = event.scope.groupId == null
        ? _watchFeed(const WatchFeedParams())
        : _watchGroupFeed(WatchGroupFeedParams(groupId: event.scope.groupId!));
    _sub = stream.listen((r) => add(_PostsFeedReceived(r)));
  }

  void _onReceived(_PostsFeedReceived event, Emitter<PostsFeedState> emit) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: PostsFeedStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить ленту',
        ),
      ),
      (posts) => emit(
        state.copyWith(
          status: PostsFeedStatus.ready,
          posts: posts,
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _onReset(
    PostsFeedResetRequested event,
    Emitter<PostsFeedState> emit,
  ) async {
    await _sub?.cancel();
    _sub = null;
    _currentScope = null;
    emit(const PostsFeedState.initial());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
