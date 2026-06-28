import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/user_profile.dart';
import '../models/user_profile_dto.dart';

/// Контракт удалённого источника данных для профилей. Все методы могут
/// выбрасывать `ServerException` при сбоях Firestore — repository
/// оборачивает их в `Failure`.
abstract interface class UserRemoteDataSource {
  Future<UserProfile?> getUser(String userId);
  Stream<UserProfile?> watchUser(String userId);
  Future<UserProfile> ensureUserDocument({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
  });
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? photoUrl,
  });

  // ========== Username-specific methods ==========

  /// Проверяет доступность username (case-insensitive).
  ///
  /// Выполняет запрос к Firestore с фильтром по `usernameLowercase`.
  /// Возвращает `true` если username свободен, `false` если занят.
  Future<bool> isUsernameAvailable(String username);

  /// Обновляет username пользователя.
  ///
  /// Обновляет поля `username`, `usernameLowercase`, `usernameLastChangedAt`
  /// в документе `users/{userId}`. Также обновляет `updatedAt`.
  Future<void> updateUsername(String userId, String newUsername);

  /// Получает профиль пользователя по username (case-insensitive).
  ///
  /// Выполняет запрос к Firestore с фильтром по `usernameLowercase`.
  /// Возвращает `null` если пользователь с таким username не найден.
  Future<UserProfile?> getUserByUsername(String username);
}

/// Реализация поверх `cloud_firestore`. Все запросы идут в коллекцию `users`.
@LazySingleton(as: UserRemoteDataSource)
final class FirestoreUserRemoteDataSource implements UserRemoteDataSource {
  FirestoreUserRemoteDataSource(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _collection = 'users';

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection(_collection);

  @override
  Future<UserProfile?> getUser(String userId) async {
    try {
      final snap = await _users.doc(userId).get();
      return UserProfileDto.fromSnapshot(snap);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Stream<UserProfile?> watchUser(String userId) {
    return _users.doc(userId).snapshots().map(UserProfileDto.fromSnapshot);
  }

  @override
  Future<UserProfile> ensureUserDocument({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final doc = _users.doc(userId);
      final snap = await doc.get();
      if (snap.exists) {
        return UserProfileDto.fromSnapshot(snap)!;
      }
      final now = DateTime.now();
      final profile = UserProfile(
        id: userId,
        displayName: displayName,
        email: email,
        photoUrl: photoUrl,
        createdAt: now,
        updatedAt: now,
      );
      await doc.set(UserProfileDto.toFirestoreMap(profile));
      return profile;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    final updates = <String, dynamic>{};
    if (displayName != null) updates[UserProfileDto.fDisplayName] = displayName;
    if (bio != null) updates[UserProfileDto.fBio] = bio;
    if (photoUrl != null) updates[UserProfileDto.fPhotoUrl] = photoUrl;
    
    if (updates.isEmpty) return;
    updates[UserProfileDto.fUpdatedAt] = Timestamp.fromDate(DateTime.now());
    try {
      await _users.doc(userId).update(updates);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  // ========== Username-specific methods ==========

  @override
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final lowercase = username.toLowerCase();
      final query = await _users
          .where(UserProfileDto.fUsernameLowercase, isEqualTo: lowercase)
          .limit(1)
          .get();
      return query.docs.isEmpty;
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<void> updateUsername(String userId, String newUsername) async {
    try {
      final updates = <String, dynamic>{
        UserProfileDto.fUsername: newUsername,
        UserProfileDto.fUsernameLowercase: newUsername.toLowerCase(),
        UserProfileDto.fUsernameLastChangedAt: FieldValue.serverTimestamp(),
        UserProfileDto.fUpdatedAt: FieldValue.serverTimestamp(),
      };
      await _users.doc(userId).update(updates);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }

  @override
  Future<UserProfile?> getUserByUsername(String username) async {
    try {
      final lowercase = username.toLowerCase();
      final query = await _users
          .where(UserProfileDto.fUsernameLowercase, isEqualTo: lowercase)
          .limit(1)
          .get();
      
      if (query.docs.isEmpty) return null;
      return UserProfileDto.fromSnapshot(query.docs.first);
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    }
  }
}
