part of 'who_liked_bloc.dart';

sealed class WhoLikedEvent extends Equatable {
  const WhoLikedEvent();

  @override
  List<Object?> get props => const [];
}

final class WhoLikedSubscribeRequested extends WhoLikedEvent {
  const WhoLikedSubscribeRequested(this.postId);
  final String postId;

  @override
  List<Object?> get props => [postId];
}

final class _WhoLikedReceived extends WhoLikedEvent {
  const _WhoLikedReceived(this.result);
  final Either<Failure, List<Like>> result;

  @override
  List<Object?> get props => [result];
}
