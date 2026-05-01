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

final class PostsFeedResetRequested extends PostsFeedEvent {
  const PostsFeedResetRequested();
}

/// Внутреннее событие — приходит из стрима репозитория.
final class _PostsFeedReceived extends PostsFeedEvent {
  const _PostsFeedReceived(this.result);
  final Either<Failure, List<Post>> result;

  @override
  List<Object?> get props => [result];
}
