import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

/// Топ коллекционеров для раздела «Топы» (по числу банок).
@lazySingleton
class TopCollectors {
  const TopCollectors(this._repository);

  final UserRepository _repository;

  ResultFuture<List<UserProfile>> call({int limit = 50}) =>
      _repository.topCollectors(limit: limit);
}
