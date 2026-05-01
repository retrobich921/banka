import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/like_post.dart';
import '../../domain/usecases/unlike_post.dart';
import '../../domain/usecases/watch_has_liked.dart';

part 'like_button_state.dart';

/// Управляет состоянием одной кнопки лайка.
///
/// Источник правды о «лайкал ли я» — стрим `watchHasLiked` (подколлекция
/// `posts/{postId}/likes/{userId}`). Чтобы не ждать round-trip + пересчёт
/// `likesCount` Cloud Function-ом, делаем оптимистичный UI:
/// - сразу выставляем `optimisticHasLiked = !hasLiked` и инкремент/декремент
///   локальной поправки `optimisticDelta` (±1) — её прибавляем к `likesCount`
///   из родителя при отрисовке;
/// - при сетевой ошибке откатываем optimistic и эмитим `errorMessage`;
/// - когда стрим присылает нужное значение `hasLiked`, optimistic
///   сбрасывается.
@injectable
class LikeButtonCubit extends Cubit<LikeButtonState> {
  LikeButtonCubit(this._likePost, this._unlikePost, this._watchHasLiked)
    : super(const LikeButtonState.initial());

  final LikePost _likePost;
  final UnlikePost _unlikePost;
  final WatchHasLiked _watchHasLiked;

  StreamSubscription<Either<Failure, bool>>? _sub;
  String? _postId;
  String? _userId;
  String? _userName;
  String? _userPhotoUrl;

  /// Подписаться на стрим «лайкал ли я этот пост».
  Future<void> subscribe({
    required String postId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
  }) async {
    if (_postId == postId && _userId == userId && _sub != null) return;
    _postId = postId;
    _userId = userId;
    _userName = userName;
    _userPhotoUrl = userPhotoUrl;

    await _sub?.cancel();
    _sub = _watchHasLiked(
      WatchHasLikedParams(postId: postId, userId: userId),
    ).listen(_onReceived);
  }

  void _onReceived(Either<Failure, bool> result) {
    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LikeButtonStatus.error,
          errorMessage: failure.message ?? 'Не удалось подписаться на лайки',
        ),
      ),
      (hasLiked) {
        // Если стрим догнал оптимистичное значение — снимаем optimistic.
        final reachedOptimistic =
            state.optimisticHasLiked != null &&
            state.optimisticHasLiked == hasLiked;
        emit(
          state.copyWith(
            status: LikeButtonStatus.ready,
            hasLiked: hasLiked,
            clearOptimistic: reachedOptimistic,
            // Если optimistic «дошёл», поправка больше не нужна.
            optimisticDelta: reachedOptimistic ? 0 : state.optimisticDelta,
            clearError: true,
          ),
        );
      },
    );
  }

  /// Тапнуть по кнопке. Идемпотентно — игнорируется, пока ещё не пришла
  /// первая выборка из стрима, или пока идёт предыдущий запрос.
  Future<void> toggle() async {
    final postId = _postId;
    final userId = _userId;
    final userName = _userName;
    if (postId == null || userId == null || userName == null) return;
    if (state.isMutating) return;

    final desired = !state.displayedHasLiked;
    final delta = desired ? 1 : -1;

    emit(
      state.copyWith(
        status: LikeButtonStatus.mutating,
        optimisticHasLiked: desired,
        optimisticDelta: delta,
        clearError: true,
      ),
    );

    final result = desired
        ? await _likePost(
            LikePostParams(
              postId: postId,
              userId: userId,
              userName: userName,
              userPhotoUrl: _userPhotoUrl,
            ),
          )
        : await _unlikePost(UnlikePostParams(postId: postId, userId: userId));

    result.fold(
      (failure) => emit(
        state.copyWith(
          status: LikeButtonStatus.error,
          clearOptimistic: true,
          optimisticDelta: 0,
          errorMessage: failure.message ?? 'Не удалось обновить лайк',
        ),
      ),
      (_) => emit(state.copyWith(status: LikeButtonStatus.ready)),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
