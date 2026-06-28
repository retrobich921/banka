import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/user_repository.dart';

/// Use case для обновления username пользователя.
///
/// Выполняет обновление username с валидацией и cooldown-проверкой:
/// 1. Валидирует username через репозиторий (формат, уникальность, cooldown)
/// 2. Обновляет поля `username`, `usernameLowercase`, `usernameLastChangedAt`
///    в документе `users/{userId}`
/// 3. Триггерит Cloud Function для обновления денормализованных данных
///    (authorName в постах/комментариях, displayName в GroupMember)
///
/// Возвращает `Right(void)` при успехе или `Left(Failure)` при ошибке
/// валидации или сохранения.
///
/// **Validates: Requirements 4.3, 4.5, 5.5**
@lazySingleton
class UpdateUsername implements UseCase<void, UpdateUsernameParams> {
  const UpdateUsername(this._repository);

  final UserRepository _repository;

  @override
  ResultFuture<void> call(UpdateUsernameParams params) =>
      _repository.updateUsername(params.userId, params.newUsername);
}

/// Параметры для обновления username.
///
/// - `userId`: ID пользователя, чей username нужно обновить
/// - `newUsername`: Новый username для установки
final class UpdateUsernameParams extends Equatable {
  const UpdateUsernameParams({required this.userId, required this.newUsername});

  /// ID пользователя, чей username нужно обновить
  final String userId;

  /// Новый username для установки
  final String newUsername;

  @override
  List<Object?> get props => [userId, newUsername];
}
