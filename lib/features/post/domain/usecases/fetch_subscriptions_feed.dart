import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Лента подписок: посты людей, на которых подписан пользователь, и групп,
/// в которых он состоит. Дедуп по id поста делает репозиторий.
@lazySingleton
class FetchSubscriptionsFeed
    implements UseCase<List<Post>, FetchSubscriptionsFeedParams> {
  const FetchSubscriptionsFeed(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<List<Post>> call(FetchSubscriptionsFeedParams params) =>
      _repository.subscriptionsFeed(
        authorIds: params.authorIds,
        groupIds: params.groupIds,
        limit: params.limit,
      );
}

final class FetchSubscriptionsFeedParams extends Equatable {
  const FetchSubscriptionsFeedParams({
    required this.authorIds,
    required this.groupIds,
    this.limit = 50,
  });

  final List<String> authorIds;
  final List<String> groupIds;
  final int limit;

  @override
  List<Object?> get props => [authorIds, groupIds, limit];
}
