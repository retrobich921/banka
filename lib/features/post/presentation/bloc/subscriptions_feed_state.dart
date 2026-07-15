part of 'subscriptions_feed_bloc.dart';

enum SubscriptionsFeedStatus { initial, loading, ready, error }

final class SubscriptionsFeedState extends Equatable {
  const SubscriptionsFeedState({
    this.status = SubscriptionsFeedStatus.initial,
    this.posts = const [],
    this.hasSubscriptions = true,
    this.errorMessage,
  });

  const SubscriptionsFeedState.initial() : this();

  final SubscriptionsFeedStatus status;
  final List<Post> posts;

  /// false — пользователь ни на кого не подписан и не состоит в группах;
  /// показываем подсказку вместо пустой ленты.
  final bool hasSubscriptions;
  final String? errorMessage;

  SubscriptionsFeedState copyWith({
    SubscriptionsFeedStatus? status,
    List<Post>? posts,
    bool? hasSubscriptions,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SubscriptionsFeedState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      hasSubscriptions: hasSubscriptions ?? this.hasSubscriptions,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, posts, hasSubscriptions, errorMessage];
}
