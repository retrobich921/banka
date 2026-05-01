import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/like.dart';
import '../../domain/usecases/watch_likers.dart';

part 'who_liked_event.dart';
part 'who_liked_state.dart';

/// Управляет экраном «Кто лайкнул пост».
///
/// Подписывается на стрим `watchLikers(postId)`. Список приходит уже
/// отсортированным по `createdAt desc`.
@injectable
class WhoLikedBloc extends Bloc<WhoLikedEvent, WhoLikedState> {
  WhoLikedBloc(this._watchLikers) : super(const WhoLikedState.initial()) {
    on<WhoLikedSubscribeRequested>(_onSubscribe);
    on<_WhoLikedReceived>(_onReceived);
  }

  final WatchLikers _watchLikers;

  StreamSubscription<Either<Failure, List<Like>>>? _sub;
  String? _currentPostId;

  Future<void> _onSubscribe(
    WhoLikedSubscribeRequested event,
    Emitter<WhoLikedState> emit,
  ) async {
    if (_currentPostId == event.postId && _sub != null) return;
    _currentPostId = event.postId;

    emit(state.copyWith(status: WhoLikedStatus.loading, clearError: true));

    await _sub?.cancel();
    _sub = _watchLikers(event.postId).listen((r) => add(_WhoLikedReceived(r)));
  }

  void _onReceived(_WhoLikedReceived event, Emitter<WhoLikedState> emit) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: WhoLikedStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить лайки',
        ),
      ),
      (likes) => emit(
        state.copyWith(
          status: WhoLikedStatus.ready,
          likes: likes,
          clearError: true,
        ),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
