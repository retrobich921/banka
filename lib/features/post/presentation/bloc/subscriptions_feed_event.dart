part of 'subscriptions_feed_bloc.dart';

sealed class SubscriptionsFeedEvent extends Equatable {
  const SubscriptionsFeedEvent();

  @override
  List<Object?> get props => const [];
}

/// Первая загрузка и pull-to-refresh ленты подписок.
final class SubscriptionsFeedRequested extends SubscriptionsFeedEvent {
  const SubscriptionsFeedRequested(this.userId);

  final String userId;

  @override
  List<Object?> get props => [userId];
}
