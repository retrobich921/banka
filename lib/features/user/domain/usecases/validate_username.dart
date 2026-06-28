import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/username_validation_result.dart';
import '../repositories/user_repository.dart';

/// Use case для валидации username.
///
/// Проверяет username по следующим критериям:
/// 1. **Формат**:
///    - Длина: 3-20 символов
///    - Символы: только латинские буквы (a-z, A-Z), цифры (0-9), подчёркивание (_)
///    - Не начинается с цифры
///    - Не состоит только из цифр
/// 2. **Уникальность**: username не занят другим пользователем (case-insensitive)
/// 3. **Cooldown**: с момента последнего изменения прошло >= 30 дней
///    (исключение: первое изменение после автогенерации разрешено без cooldown)
///
/// Возвращает `Right(UsernameValidationResult)` с одним из вариантов:
/// - `valid()`: username валиден и доступен
/// - `invalid(reason)`: не соответствует формату (с описанием причины)
/// - `taken()`: уже занят другим пользователем
/// - `cooldownActive(nextAvailableDate)`: cooldown активен
///
/// **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.4, 4.3, 4.4, 5.2, 5.3, 5.4**
@lazySingleton
class ValidateUsername
    implements UseCase<UsernameValidationResult, ValidateUsernameParams> {
  const ValidateUsername(this._repository);

  final UserRepository _repository;

  @override
  ResultFuture<UsernameValidationResult> call(ValidateUsernameParams params) =>
      _repository.validateUsername(params.username, params.userId);
}

/// Параметры для валидации username.
///
/// - `username`: Username для валидации
/// - `userId`: ID пользователя, который пытается установить username
final class ValidateUsernameParams extends Equatable {
  const ValidateUsernameParams({
    required this.username,
    required this.userId,
  });

  /// Username для валидации
  final String username;

  /// ID пользователя, который пытается установить username
  final String userId;

  @override
  List<Object?> get props => [username, userId];
}
