import 'package:equatable/equatable.dart';

/// Аутентифицированный пользователь — domain-сущность, не зависит от Firebase.
///
/// Содержит только то, что нужно presentation/use-case слоям. Полный
/// профиль (био, статистика, FCM-токены) живёт в `users/{userId}` в Firestore
/// и подгружается отдельным `UserRepository` в Sprint 3.
final class AuthUser extends Equatable {
  const AuthUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;

  @override
  List<Object?> get props => [id, email, displayName, photoUrl, isAnonymous];

  @override
  bool? get stringify => true;
}
