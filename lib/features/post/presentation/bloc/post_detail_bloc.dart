import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/watch_post.dart';

part 'post_detail_event.dart';
part 'post_detail_state.dart';

/// Управляет экраном детализации поста.
///
/// Подписывается на `WatchPost(id)` — это даёт live-обновления, когда
/// другой пользователь меняет лайки/комментарии (Sprint 10/11) или сам
/// автор правит описание (Sprint 9 не редактирует).
@injectable
class PostDetailBloc extends Bloc<PostDetailEvent, PostDetailState> {
  PostDetailBloc(this._watchPost) : super(const PostDetailState.initial()) {
    on<PostDetailSubscribeRequested>(_onSubscribe);
    on<_PostDetailReceived>(_onReceived);
  }

  final WatchPost _watchPost;

  StreamSubscription<Either<Failure, Post?>>? _sub;
  String? _currentPostId;

  Future<void> _onSubscribe(
    PostDetailSubscribeRequested event,
    Emitter<PostDetailState> emit,
  ) async {
    if (_currentPostId == event.postId && _sub != null) return;
    _currentPostId = event.postId;

    emit(state.copyWith(status: PostDetailStatus.loading, clearError: true));

    await _sub?.cancel();
    _sub = _watchPost(event.postId).listen((r) => add(_PostDetailReceived(r)));
  }

  void _onReceived(_PostDetailReceived event, Emitter<PostDetailState> emit) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: PostDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить пост',
        ),
      ),
      (post) {
        if (post == null) {
          emit(
            state.copyWith(status: PostDetailStatus.notFound, clearPost: true),
          );
          return;
        }
        emit(
          state.copyWith(
            status: PostDetailStatus.ready,
            post: post,
            clearError: true,
          ),
        );
      },
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
