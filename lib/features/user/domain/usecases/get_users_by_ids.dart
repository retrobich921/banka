import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

/// Профили по списку id — для экранов «Подписки» / «Подписчики».
@lazySingleton
class GetUsersByIds {
  const GetUsersByIds(this._repository);

  final UserRepository _repository;

  ResultFuture<List<UserProfile>> call(List<String> ids) =>
      _repository.getUsersByIds(ids);
}
