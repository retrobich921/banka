import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/follow_repository.dart';

/// Live-список id тех, на кого подписан пользователь.
@lazySingleton
class WatchFollowingIds {
  const WatchFollowingIds(this._repository);

  final FollowRepository _repository;

  ResultStream<List<String>> call(String userId) =>
      _repository.watchFollowingIds(userId);
}

/// Live-список id тех, кто подписан на пользователя.
@lazySingleton
class WatchFollowerIds {
  const WatchFollowerIds(this._repository);

  final FollowRepository _repository;

  ResultStream<List<String>> call(String userId) =>
      _repository.watchFollowerIds(userId);
}
