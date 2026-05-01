import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/comment.dart';
import '../../domain/usecases/watch_comments.dart';

part 'comments_event.dart';
part 'comments_state.dart';

/// Управляет real-time лентой комментариев под конкретным постом.
///
/// Поведение:
/// - При `CommentsSubscribeRequested(postId)` отписываемся от прошлой
///   подписки (если postId сменился) и открываем новую через `WatchComments`.
/// - Поток уже отсортирован по `createdAt desc` из репозитория.
/// - Дедуп subscribe: повторный `CommentsSubscribeRequested` с тем же id
///   игнорируется.
@injectable
class CommentsBloc extends Bloc<CommentsEvent, CommentsState> {
  CommentsBloc(this._watchComments) : super(const CommentsState.initial()) {
    on<CommentsSubscribeRequested>(_onSubscribe);
    on<_CommentsReceived>(_onReceived);
    on<CommentsResetRequested>(_onReset);
  }

  final WatchComments _watchComments;

  StreamSubscription<Either<Failure, List<Comment>>>? _sub;
  String? _currentPostId;

  Future<void> _onSubscribe(
    CommentsSubscribeRequested event,
    Emitter<CommentsState> emit,
  ) async {
    if (_currentPostId == event.postId && _sub != null) return;
    _currentPostId = event.postId;

    emit(
      state.copyWith(
        status: CommentsStatus.loading,
        postId: event.postId,
        clearError: true,
      ),
    );

    await _sub?.cancel();
    _sub = _watchComments(
      event.postId,
    ).listen((r) => add(_CommentsReceived(r)));
  }

  void _onReceived(_CommentsReceived event, Emitter<CommentsState> emit) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: CommentsStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить комментарии',
        ),
      ),
      (comments) => emit(
        state.copyWith(
          status: CommentsStatus.ready,
          comments: comments,
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _onReset(
    CommentsResetRequested event,
    Emitter<CommentsState> emit,
  ) async {
    await _sub?.cancel();
    _sub = null;
    _currentPostId = null;
    emit(const CommentsState.initial());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
