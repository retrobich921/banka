import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/auth_user.dart';
import '../models/auth_user_model.dart';

/// Контракт удалённого источника данных для auth.
abstract interface class AuthRemoteDataSource {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<AuthUser> signInWithGoogle();
  Future<void> signOut();
}

/// Реализация поверх `firebase_auth` + `google_sign_in` 7.x.
///
/// google_sign_in 7.x требует `GoogleSignIn.instance.initialize()` ровно
/// один раз — делаем это лениво при первом обращении.
@LazySingleton(as: AuthRemoteDataSource)
final class FirebaseAuthRemoteDataSource implements AuthRemoteDataSource {
  FirebaseAuthRemoteDataSource(this._firebaseAuth, this._googleSignIn);

  final fb.FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  Future<void>? _initializing;

  /// Web OAuth client ID из Firebase / google-services.json (oauth_client с
  /// `client_type: 3`). На Android google_sign_in 7.x не сможет вернуть
  /// валидный `idToken` для Firebase без `serverClientId` — Credential Manager
  /// просто не запустит флоу или вернёт пустой токен.
  static const String _serverClientId =
      '118303358012-7qn2tfn87357e0u1ac57bvr9ush5fmg6.apps.googleusercontent.com';

  Future<void> _ensureGoogleInitialized() {
    return _initializing ??= _googleSignIn.initialize(
      serverClientId: _serverClientId,
    );
  }

  @override
  Stream<AuthUser?> authStateChanges() =>
      _firebaseAuth.authStateChanges().map((user) => user?.toDomain());

  @override
  AuthUser? get currentUser => _firebaseAuth.currentUser?.toDomain();

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      await _ensureGoogleInitialized();

      final GoogleSignInAccount account = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile'],
      );
      final GoogleSignInAuthentication googleAuth = account.authentication;
      final String? idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const AuthException(message: 'Google вернул пустой idToken');
      }

      final fb.AuthCredential credential = fb.GoogleAuthProvider.credential(
        idToken: idToken,
      );

      final fb.UserCredential userCred = await _firebaseAuth
          .signInWithCredential(credential);
      final fb.User? user = userCred.user;
      if (user == null) {
        throw const AuthException(
          message: 'Firebase не вернул пользователя после signInWithCredential',
        );
      }
      
      // Обновляем displayName из Google аккаунта, если он не установлен
      if ((user.displayName == null || user.displayName!.isEmpty) && 
          account.displayName != null) {
        await user.updateDisplayName(account.displayName);
        await user.reload();
        final updatedUser = _firebaseAuth.currentUser;
        if (updatedUser != null) {
          return updatedUser.toDomain();
        }
      }
      
      return user.toDomain();
    } on GoogleSignInException catch (e) {
      throw AuthException(
        message: 'Google sign-in отменён или недоступен (${e.code.name})',
        cause: e,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(
        message: e.message ?? 'Firebase auth error: ${e.code}',
        cause: e,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(message: e.toString(), cause: e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureGoogleInitialized();
      // Сначала выходим из Google, чтобы при следующем входе показывался
      // chooser, потом из Firebase.
      await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (e) {
      throw AuthException(message: 'Ошибка выхода: $e', cause: e);
    }
  }
}
