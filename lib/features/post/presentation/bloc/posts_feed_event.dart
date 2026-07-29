part of 'posts_feed_bloc.dart';

sealed class PostsFeedEvent extends Equatable {
  const PostsFeedEvent();

  @override
  List<Object?> get props => const [];
}

/// Запросить подписку на ленту в указанном скоупе.
final class PostsFeedSubscribeRequested extends PostsFeedEvent {
  const PostsFeedSubscribeRequested(this.scope);
  final PostsFeedScope scope;

  @override
  List<Object?> get props => [scope];
}

/// Догрузить следующую страницу ленты (расширить окно подписки).
final class PostsFeedLoadMoreRequested extends PostsFeedEvent {
  const PostsFeedLoadMoreRequested();
}

final class PostsFeedResetRequested extends PostsFeedEvent {
  const PostsFeedResetRequested();
}

/// Убрать пост из ленты локально — например, после архивации.
///
/// Realtime-стрим отдаёт только первую страницу, поэтому у догруженных
/// пагинацией постов «archived» сам собой не приедет; плюс так карточка
/// исчезает сразу, без ожидания round-trip.
final class PostsFeedPostHidden extends PostsFeedEvent {
  const PostsFeedPostHidden(this.postId);
  final String postId;

  @override
  List<Object?> get props => [postId];
}

/// Внутреннее событие — приходит из стрима репозитория.
final class _PostsFeedReceived extends PostsFeedEvent {
  const _PostsFeedReceived(this.result);
  final Either<Failure, List<Post>> result;

  @override
  List<Object?> get props => [result];
}
