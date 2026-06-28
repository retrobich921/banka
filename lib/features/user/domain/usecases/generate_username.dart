import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/user_repository.dart';

/// Use case для генерации уникального username.
///
/// Генерирует username на основе displayName или случайным образом, если
/// displayName не предоставлен или все варианты на его основе заняты.
///
/// Алгоритм:
/// 1. Если `displayName` предоставлен:
///    - Удаляет недопустимые символы (оставляет только буквы, цифры, подчёркивание)
///    - Приводит к lowercase
///    - Обрезает до 20 символов
///    - Проверяет доступность
/// 2. Если недоступен, пробует добавить цифры (1-999)
/// 3. Если все варианты заняты или displayName не предоставлен:
///    - Генерирует случайный username в формате "user_XXXXXX" (6 случайных цифр)
/// 4. Валидирует формат и уникальность перед возвратом
///
/// Возвращает `Right(username)` при успехе или `Left(Failure)` при ошибке
/// (например, не удалось сгенерировать уникальный username после 10 попыток).
///
/// **Validates: Requirements 1.1, 1.2, 1.5**
@lazySingleton
class GenerateUsername implements UseCase<String, GenerateUsernameParams> {
  const GenerateUsername(this._repository);

  final UserRepository _repository;

  @override
  ResultFuture<String> call(GenerateUsernameParams params) =>
      _repository.generateUniqueUsername(params.displayName);
}

/// Параметры для генерации username.
///
/// - `displayName`: Опциональное имя пользователя из Google аккаунта.
///   Если предоставлено, будет использовано как основа для генерации username.
///   Если `null` или пустое, будет сгенерирован случайный username.
final class GenerateUsernameParams extends Equatable {
  const GenerateUsernameParams({this.displayName});

  /// Имя пользователя из Google аккаунта (опционально).
  final String? displayName;

  @override
  List<Object?> get props => [displayName];
}
