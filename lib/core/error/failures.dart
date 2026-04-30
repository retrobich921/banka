import 'package:equatable/equatable.dart';

/// Базовый класс для всех доменных ошибок.
///
/// `Failure` — то, что возвращается из `data`-слоя в `domain` через `Either`.
/// Конкретные подклассы создаются в фичах под их специфику.
sealed class Failure extends Equatable {
  const Failure({this.message, this.cause});

  final String? message;
  final Object? cause;

  @override
  List<Object?> get props => [runtimeType, message];
}

final class ServerFailure extends Failure {
  const ServerFailure({super.message, super.cause});
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message, super.cause});
}

final class CacheFailure extends Failure {
  const CacheFailure({super.message, super.cause});
}

final class AuthFailure extends Failure {
  const AuthFailure({super.message, super.cause});
}

final class PermissionFailure extends Failure {
  const PermissionFailure({super.message, super.cause});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({super.message, super.cause});
}

final class UnknownFailure extends Failure {
  const UnknownFailure({super.message, super.cause});
}
