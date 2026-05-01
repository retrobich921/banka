import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

@lazySingleton
class WatchUser implements StreamResultUseCase<UserProfile?, String> {
  const WatchUser(this._repository);

  final UserRepository _repository;

  @override
  ResultStream<UserProfile?> call(String userId) =>
      _repository.watchUser(userId);
}
