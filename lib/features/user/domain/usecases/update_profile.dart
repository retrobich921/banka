import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/user_repository.dart';

/// Параметры частичного обновления профиля. `null` — поле не трогаем.
final class UpdateProfileParams extends Equatable {
  const UpdateProfileParams({
    required this.userId,
    this.displayName,
    this.bio,
    this.photoUrl,
  });

  final String userId;
  final String? displayName;
  final String? bio;
  final String? photoUrl;

  @override
  List<Object?> get props => [userId, displayName, bio, photoUrl];
}

@lazySingleton
class UpdateProfile implements UseCase<void, UpdateProfileParams> {
  const UpdateProfile(this._repository);

  final UserRepository _repository;

  @override
  ResultFuture<void> call(UpdateProfileParams params) =>
      _repository.updateProfile(
        userId: params.userId,
        displayName: params.displayName,
        bio: params.bio,
        photoUrl: params.photoUrl,
      );
}
