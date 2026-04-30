/// Исключения, бросаемые в `data`-слое (datasource → repository).
///
/// Repository ловит их и оборачивает в `Failure`, чтобы `domain` и
/// `presentation` оперировали только `Either<Failure, T>` и не зависели
/// от Firebase/HTTP-специфики.
sealed class AppException implements Exception {
  const AppException({this.message, this.cause});

  final String? message;
  final Object? cause;

  @override
  String toString() => '$runtimeType(${message ?? ''})';
}

class ServerException extends AppException {
  const ServerException({super.message, super.cause});
}

class NetworkException extends AppException {
  const NetworkException({super.message, super.cause});
}

class CacheException extends AppException {
  const CacheException({super.message, super.cause});
}

class AuthException extends AppException {
  const AuthException({super.message, super.cause});
}

class PermissionException extends AppException {
  const PermissionException({super.message, super.cause});
}

class ValidationException extends AppException {
  const ValidationException({super.message, super.cause});
}
