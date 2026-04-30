import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/auth_user.dart';
import '../repositories/auth_repository.dart';

@lazySingleton
class SignInWithGoogle implements UseCase<AuthUser, NoParams> {
  const SignInWithGoogle(this._repository);

  final AuthRepository _repository;

  @override
  ResultFuture<AuthUser> call(NoParams params) =>
      _repository.signInWithGoogle();
}
