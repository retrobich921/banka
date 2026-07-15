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

/// Автор архивирует пост или возвращает его из архива.
final class PostDetailArchiveToggleRequested extends PostDetailEvent {
  const PostDetailArchiveToggleRequested({required this.archived});

  /// Целевое состояние: true — в архив, false — вернуть.
  final bool archived;

  @override
  List<Object?> get props => [archived];
}

/// Автор запросил удаление своего поста (после подтверждения в UI).
final class PostDetailDeleteRequested extends PostDetailEvent {
  const PostDetailDeleteRequested();
}

final class _PostDetailReceived extends PostDetailEvent {
  const _PostDetailReceived(this.result);
  final Either<Failure, Post?> result;

  @override
  List<Object?> get props => [result];
}
