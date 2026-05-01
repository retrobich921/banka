part of 'post_detail_bloc.dart';

sealed class PostDetailEvent extends Equatable {
  const PostDetailEvent();

  @override
  List<Object?> get props => const [];
}

final class PostDetailSubscribeRequested extends PostDetailEvent {
  const PostDetailSubscribeRequested(this.postId);
  final String postId;

  @override
  List<Object?> get props => [postId];
}

final class _PostDetailReceived extends PostDetailEvent {
  const _PostDetailReceived(this.result);
  final Either<Failure, Post?> result;

  @override
  List<Object?> get props => [result];
}
