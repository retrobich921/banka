import '../../../../core/utils/typedefs.dart';
import '../entities/auth_user.dart';

/// Контракт auth-репозитория. Реализация в `data/` инкапсулирует
/// `firebase_auth` и `google_sign_in` и не утекает в presentation.
abstract interface class AuthRepository {
  /// Поток текущего пользователя. `null` означает "не залогинен".
  Stream<AuthUser?> watchAuthState();

  /// Текущий синхронный снимок (например, для splash-редиректа).
  AuthUser? get currentUser;

  /// Запускает Google OAuth flow и логин в Firebase. Возвращает
  /// `Right(AuthUser)` при успехе, `Left(Failure)` при отмене/ошибке.
  ResultFuture<AuthUser> signInWithGoogle();

  /// Sign-out и из Firebase, и из Google (чтобы в следующий раз показывался
  /// chooser, а не молча восстанавливался предыдущий аккаунт).
  ResultFuture<void> signOut();
}
