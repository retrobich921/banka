import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../repositories/user_repository.dart';

/// Параметры создания/проверки `users/{uid}` после первого sign-in.
final class EnsureUserDocumentParams extends Equatable {
  const EnsureUserDocumentParams({
    required this.userId,
    required this.email,
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String email;
  final String displayName;
  final String? photoUrl;

  @override
  List<Object?> get props => [userId, email, displayName, photoUrl];
}

@lazySingleton
class EnsureUserDocument
    implements UseCase<UserProfile, EnsureUserDocumentParams> {
  const EnsureUserDocument(this._repository);

  final UserRepository _repository;

  @override
  ResultFuture<UserProfile> call(EnsureUserDocumentParams params) =>
      _repository.ensureUserDocument(
        userId: params.userId,
        email: params.email,
        displayName: params.displayName,
        photoUrl: params.photoUrl,
      );
}
