import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/delete_post.dart';
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
  PostDetailBloc(this._watchPost, this._deletePost)
    : super(const PostDetailState.initial()) {
    on<PostDetailSubscribeRequested>(_onSubscribe);
    on<PostDetailDeleteRequested>(_onDeleteRequested);
    on<_PostDetailReceived>(_onReceived);
  }

  final WatchPost _watchPost;
  final DeletePost _deletePost;

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

  Future<void> _onDeleteRequested(
    PostDetailDeleteRequested event,
    Emitter<PostDetailState> emit,
  ) async {
    final postId = _currentPostId;
    if (postId == null || state.status == PostDetailStatus.deleting) return;

    emit(state.copyWith(status: PostDetailStatus.deleting, clearError: true));
    // Отписываемся до удаления, чтобы стрим не перевёл экран в notFound.
    await _sub?.cancel();
    _sub = null;

    final result = await _deletePost(postId);
    result.fold((failure) {
      emit(
        state.copyWith(
          status: PostDetailStatus.error,
          errorMessage: failure.message ?? 'Не удалось удалить пост',
        ),
      );
      // Возвращаем live-подписку, пост всё ещё существует.
      _sub = _watchPost(postId).listen((r) => add(_PostDetailReceived(r)));
    }, (_) => emit(state.copyWith(status: PostDetailStatus.deleted)));
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
