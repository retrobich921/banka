import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

@lazySingleton
class WatchUserStats implements StreamResultUseCase<UserStats?, String> {
  const WatchUserStats(this._repository);

  final UserRepository _repository;

  @override
  ResultStream<UserStats?> call(String userId) =>
      _repository.watchUserStats(userId);
}
