import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../domain/entities/auth_user.dart';

/// Маппинг между `firebase_auth.User` и доменной `AuthUser`.
///
/// Domain-слой не должен видеть тип `firebase_auth.User`, поэтому конверсия
/// делается в data-слое и наружу выходит уже `AuthUser`.
extension FirebaseUserToDomain on fb.User {
  AuthUser toDomain() => AuthUser(
    id: uid,
    email: email ?? '',
    displayName: displayName,
    photoUrl: photoURL,
    isAnonymous: isAnonymous,
  );
}
