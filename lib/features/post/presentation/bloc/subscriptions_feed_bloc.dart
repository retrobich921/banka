import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';

import '../../../follow/domain/usecases/get_following_ids.dart';
import '../../../group/domain/usecases/watch_my_groups.dart';
import '../../domain/entities/post.dart';
import '../../domain/usecases/fetch_subscriptions_feed.dart';

part 'subscriptions_feed_event.dart';
part 'subscriptions_feed_state.dart';

/// Лента «Подписки» на главном экране (VK-style): собирает id людей, на
/// которых подписан пользователь, и групп, в которых он состоит, и грузит
/// объединённую ленту их постов. Обновление — pull-to-refresh (повторный
/// `SubscriptionsFeedRequested`).
@injectable
class SubscriptionsFeedBloc
    extends Bloc<SubscriptionsFeedEvent, SubscriptionsFeedState> {
  SubscriptionsFeedBloc(
    this._getFollowingIds,
    this._watchMyGroups,
    this._fetchFeed,
  ) : super(const SubscriptionsFeedState.initial()) {
    on<SubscriptionsFeedRequested>(_onRequested);
  }

  final GetFollowingIds _getFollowingIds;
  final WatchMyGroups _watchMyGroups;
  final FetchSubscriptionsFeed _fetchFeed;

  Future<void> _onRequested(
    SubscriptionsFeedRequested event,
    Emitter<SubscriptionsFeedState> emit,
  ) async {
    // При refresh список уже на экране — не скидываем в спиннер.
    if (state.posts.isEmpty) {
      emit(state.copyWith(status: SubscriptionsFeedStatus.loading));
    }

    final followingResult = await _getFollowingIds(event.userId);
    final followedUserIds = followingResult.fold(
      (_) => const <String>[],
      (ids) => ids,
    );

    final groupsResult = await _watchMyGroups(event.userId).first;
    final groupIds = groupsResult.fold(
      (_) => const <String>[],
      (groups) => groups.map((g) => g.id).toList(growable: false),
    );

    if (followedUserIds.isEmpty && groupIds.isEmpty) {
      emit(
        state.copyWith(
          status: SubscriptionsFeedStatus.ready,
          posts: const [],
          hasSubscriptions: false,
        ),
      );
      return;
    }

    final feedResult = await _fetchFeed(
      FetchSubscriptionsFeedParams(
        authorIds: followedUserIds,
        groupIds: groupIds,
      ),
    );
    feedResult.fold(
      (failure) => emit(
        state.copyWith(
          status: SubscriptionsFeedStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить ленту',
        ),
      ),
      (posts) => emit(
        state.copyWith(
          status: SubscriptionsFeedStatus.ready,
          posts: posts,
          hasSubscriptions: true,
          clearError: true,
        ),
      ),
    );
  }
}
