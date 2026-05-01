part of 'comments_bloc.dart';

sealed class CommentsEvent extends Equatable {
  const CommentsEvent();

  @override
  List<Object?> get props => [];
}

/// Подписаться на стрим комментариев конкретного поста.
final class CommentsSubscribeRequested extends CommentsEvent {
  const CommentsSubscribeRequested(this.postId);

  final String postId;

  @override
  List<Object?> get props => [postId];
}

/// Сбросить состояние и отписаться. Используется при выходе с экрана.
final class CommentsResetRequested extends CommentsEvent {
  const CommentsResetRequested();
}

/// Внутреннее событие — пришёл результат из стрима.
final class _CommentsReceived extends CommentsEvent {
  const _CommentsReceived(this.result);

  final Either<Failure, List<Comment>> result;

  @override
  List<Object?> get props => [result];
}
