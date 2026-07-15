import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/usecases/follow_user.dart';
import '../../domain/usecases/unfollow_user.dart';
import '../../domain/usecases/watch_is_following.dart';

/// Состояние кнопки подписки: known=false пока не пришёл первый снапшот.
final class FollowButtonState extends Equatable {
  const FollowButtonState({
    this.known = false,
    this.isFollowing = false,
    this.busy = false,
  });

  final bool known;
  final bool isFollowing;
  final bool busy;

  FollowButtonState copyWith({bool? known, bool? isFollowing, bool? busy}) =>
      FollowButtonState(
        known: known ?? this.known,
        isFollowing: isFollowing ?? this.isFollowing,
        busy: busy ?? this.busy,
      );

  @override
  List<Object?> get props => [known, isFollowing, busy];
}

/// Кубит кнопки «Подписаться» на профиле пользователя. Живёт, пока кнопка
/// в дереве; подписан на live-флаг `watchIsFollowing`, тап делает
/// follow/unfollow с оптимистичным переключением.
@injectable
class FollowButtonCubit extends Cubit<FollowButtonState> {
  FollowButtonCubit(this._followUser, this._unfollowUser, this._watch)
    : super(const FollowButtonState());

  final FollowUser _followUser;
  final UnfollowUser _unfollowUser;
  final WatchIsFollowing _watch;

  StreamSubscription<Either<Failure, bool>>? _sub;
  FollowParams? _params;

  void subscribe({required String followerId, required String targetUserId}) {
    _params = FollowParams(followerId: followerId, targetUserId: targetUserId);
    _sub?.cancel();
    _sub = _watch(_params!).listen((r) {
      r.fold(
        (_) {},
        (following) =>
            emit(state.copyWith(known: true, isFollowing: following)),
      );
    });
  }

  Future<void> toggle() async {
    final params = _params;
    if (params == null || state.busy || !state.known) return;
    final wasFollowing = state.isFollowing;
    emit(state.copyWith(busy: true, isFollowing: !wasFollowing));
    final result = wasFollowing
        ? await _unfollowUser(params)
        : await _followUser(params);
    result.fold(
      // Откат оптимистичного переключения при ошибке.
      (_) => emit(state.copyWith(busy: false, isFollowing: wasFollowing)),
      (_) => emit(state.copyWith(busy: false)),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
