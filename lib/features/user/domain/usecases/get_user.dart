import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

@lazySingleton
class GetUser implements UseCase<UserProfile?, String> {
  const GetUser(this._repository);

  final UserRepository _repository;

  @override
  ResultFuture<UserProfile?> call(String userId) => _repository.getUser(userId);
}
