import '../../../../core/utils/typedefs.dart';
import '../entities/user_profile.dart';

/// Контракт репозитория профилей пользователей.
///
/// Все методы возвращают `Either<Failure, T>` (через `ResultFuture`/`ResultStream`)
/// — никаких голых исключений в presentation/usecase'ы не пробрасываем.
abstract interface class UserRepository {
  /// Разовый снимок профиля по `userId`. `Right(null)` — документ не существует.
  ResultFuture<UserProfile?> getUser(String userId);

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
}
