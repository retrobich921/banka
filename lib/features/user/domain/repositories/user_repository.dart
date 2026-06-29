import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';
import '../entities/username_validation_result.dart';

/// Контракт репозитория профилей пользователей.
///
/// Все методы возвращают `Either<Failure, T>` (через `ResultFuture`/`ResultStream`)
/// — никаких голых исключений в presentation/usecase'ы не пробрасываем.
abstract interface class UserRepository {
  /// Разовый снимок профиля по `userId`. `Right(null)` — документ не существует.
  ResultFuture<UserProfile?> getUser(String userId);

  /// Топ коллекционеров — пользователи по числу банок (`stats.cansCount` desc).
  ResultFuture<List<UserProfile>> topCollectors({int limit = 50});

  /// Real-time стрим профиля. Эмитит `null`, когда документ удалён или ещё
  /// не создан (например, между `signInWithGoogle` и `ensureUserDocument`).
  ResultStream<UserProfile?> watchUser(String userId);

  /// Стрим только подобъекта `stats` — удобнее для виджетов, которые хотят
  /// перерисовываться от изменений статистики и не зависеть от bio/photoUrl.
  ResultStream<UserStats?> watchUserStats(String userId);

  /// Создаёт документ `users/{uid}` если его ещё нет. Идемпотентно: при
  /// повторном вызове ничего не делает (использует Firestore `set(..., merge)`
  /// только для отсутствующих полей).
  ///
  /// Используется AuthBloc'ом сразу после первого `signInWithGoogle` — пока
  /// нет Cloud Function'а в Sprint 18, это делается с клиента.
  ResultFuture<UserProfile> ensureUserDocument({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
  });

  /// Частичный апдейт «редактируемых пользователем» полей. Поля, переданные
  /// как `null`, остаются нетронутыми; чтобы очистить bio, передай пустую
  /// строку.
  ResultFuture<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? photoUrl,
  });

  // ========== Username-specific methods ==========

  /// Проверяет доступность username (case-insensitive).
  ///
  /// Возвращает `Right(true)` если username свободен, `Right(false)` если занят.
  /// Используется для валидации и генерации уникальных username.
  ResultFuture<bool> isUsernameAvailable(String username);

  /// Генерирует уникальный username на основе displayName или случайным образом.
  ///
  /// Алгоритм:
  /// 1. Если `displayName` предоставлен — санитизирует его (удаляет спецсимволы,
  ///    приводит к lowercase, обрезает до 20 символов)
  /// 2. Проверяет доступность санитизированного имени
  /// 3. Если занято — пробует добавить цифры (1-999)
  /// 4. Если все варианты заняты или displayName не предоставлен — генерирует
  ///    случайный username в формате "user_XXXXXX" (6 случайных цифр)
  /// 5. Валидирует формат и уникальность перед возвратом
  ///
  /// Возвращает `Right(username)` при успехе или `Left(Failure)` при ошибке
  /// (например, не удалось сгенерировать уникальный username после 10 попыток).
  ResultFuture<String> generateUniqueUsername(String? displayName);

  /// Валидирует username по формату, уникальности и cooldown-периоду.
  ///
  /// Проверяет:
  /// - Формат: длина 3-20 символов, только буквы (a-z, A-Z), цифры (0-9),
  ///   подчёркивание (_), не начинается с цифры, не состоит только из цифр
  /// - Уникальность: username не занят другим пользователем (case-insensitive)
  /// - Cooldown: с момента последнего изменения прошло >= 30 дней
  ///   (исключение: первое изменение после автогенерации разрешено без cooldown)
  ///
  /// Параметры:
  /// - `username`: username для валидации
  /// - `userId`: ID пользователя, который пытается установить username
  ///
  /// Возвращает `Right(UsernameValidationResult)` с результатом валидации:
  /// - `valid()`: username валиден и доступен
  /// - `invalid(reason)`: не соответствует формату
  /// - `taken()`: уже занят другим пользователем
  /// - `cooldownActive(nextAvailableDate)`: cooldown активен
  ResultFuture<UsernameValidationResult> validateUsername(
    String username,
    String userId,
  );

  /// Обновляет username пользователя с валидацией и cooldown-проверкой.
  ///
  /// Выполняет:
  /// 1. Валидацию username через `validateUsername`
  /// 2. Обновление полей `username`, `usernameLowercase`, `usernameLastChangedAt`
  ///    в документе `users/{userId}`
  /// 3. Триггер Cloud Function для обновления денормализованных данных
  ///    (authorName в постах/комментариях, displayName в GroupMember)
  ///
  /// Возвращает `Right(void)` при успехе или `Left(Failure)` при ошибке
  /// валидации или сохранения.
  ResultFuture<void> updateUsername(String userId, String newUsername);
}
