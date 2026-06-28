import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/username_validation_result.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/user_remote_data_source.dart';

@LazySingleton(as: UserRepository)
final class UserRepositoryImpl implements UserRepository {
  UserRepositoryImpl(this._remote);

  final UserRemoteDataSource _remote;

  @override
  ResultFuture<UserProfile?> getUser(String userId) async {
    try {
      final user = await _remote.getUser(userId);
      return Right(user);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<UserProfile?> watchUser(String userId) async* {
    try {
      await for (final profile in _remote.watchUser(userId)) {
        yield Right<Failure, UserProfile?>(profile);
      }
    } on ServerException catch (e) {
      yield Left<Failure, UserProfile?>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, UserProfile?>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultStream<UserStats?> watchUserStats(String userId) {
    return watchUser(
      userId,
    ).map((either) => either.map((profile) => profile?.stats));
  }

  @override
  ResultFuture<UserProfile> ensureUserDocument({
    required String userId,
    required String email,
    required String displayName,
    String? photoUrl,
  }) async {
    try {
      final profile = await _remote.ensureUserDocument(
        userId: userId,
        email: email,
        displayName: displayName,
        photoUrl: photoUrl,
      );
      return Right(profile);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    try {
      await _remote.updateProfile(
        userId: userId,
        displayName: displayName,
        bio: bio,
        photoUrl: photoUrl,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  // ========== Username-specific methods ==========

  @override
  ResultFuture<bool> isUsernameAvailable(String username) async {
    try {
      final available = await _remote.isUsernameAvailable(username);
      return Right(available);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<String> generateUniqueUsername(String? displayName) async {
    try {
      // Попытка генерации на основе displayName
      if (displayName != null && displayName.isNotEmpty) {
        final sanitized = _sanitizeDisplayName(displayName);
        if (sanitized.isNotEmpty) {
          // Проверяем базовый вариант
          if (await _remote.isUsernameAvailable(sanitized)) {
            return Right(sanitized);
          }
          // Пробуем с цифрами 1-999
          for (var i = 1; i <= 999; i++) {
            final candidate = '$sanitized$i';
            if (candidate.length <= 20 &&
                await _remote.isUsernameAvailable(candidate)) {
              return Right(candidate);
            }
          }
        }
      }

      // Fallback: генерируем случайный username
      final random = Random();
      for (var attempt = 0; attempt < 10; attempt++) {
        final randomDigits = List.generate(6, (_) => random.nextInt(10)).join();
        final candidate = 'user_$randomDigits';
        if (await _remote.isUsernameAvailable(candidate)) {
          return Right(candidate);
        }
      }

      return const Left(
        ServerFailure(
          message: 'Не удалось сгенерировать username, попробуйте позже',
        ),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<UsernameValidationResult> validateUsername(
    String username,
    String userId,
  ) async {
    try {
      // 1. Проверка формата
      final formatError = _validateFormat(username);
      if (formatError != null) {
        return Right(UsernameValidationResult.invalid(formatError));
      }

      // 2. Получаем текущий профиль для проверки cooldown
      final currentProfile = await _remote.getUser(userId);

      // 3. Проверка уникальности (если username изменился)
      if (currentProfile?.username != username) {
        final existingUser = await _remote.getUserByUsername(username);
        if (existingUser != null && existingUser.id != userId) {
          return const Right(UsernameValidationResult.taken());
        }
      }

      // 4. Проверка cooldown (если username изменился)
      if (currentProfile?.username != username &&
          currentProfile?.usernameLastChangedAt != null) {
        final lastChanged = currentProfile!.usernameLastChangedAt!;
        final daysSince = DateTime.now().difference(lastChanged).inDays;
        if (daysSince < 30) {
          final nextAvailable = lastChanged.add(const Duration(days: 30));
          return Right(
            UsernameValidationResult.cooldownActive(
              nextAvailableDate: nextAvailable,
            ),
          );
        }
      }

      return const Right(UsernameValidationResult.valid());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> updateUsername(String userId, String newUsername) async {
    try {
      // Валидация перед обновлением
      final validationResult = await validateUsername(newUsername, userId);
      return validationResult.fold(Left.new, (result) async {
        // Проверяем результат валидации
        return result.when(
          valid: () async {
            await _remote.updateUsername(userId, newUsername);
            return const Right(null);
          },
          invalid: (reason) => const Left(
            ServerFailure(message: 'Username не соответствует формату'),
          ),
          taken: () => const Left(
            ServerFailure(message: 'Username уже занят, выберите другой'),
          ),
          cooldownActive: (nextDate) => const Left(
            ServerFailure(
              message: 'Username можно изменить только раз в 30 дней',
            ),
          ),
        );
      });
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  // ========== Helper methods ==========

  /// Санитизирует displayName для использования в качестве username.
  ///
  /// Удаляет недопустимые символы, приводит к lowercase, обрезает до 20 символов.
  String _sanitizeDisplayName(String displayName) {
    // Удаляем все символы кроме букв, цифр и подчёркивания
    var sanitized = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'^[0-9]+'), ''); // Удаляем ведущие цифры

    // Обрезаем до 20 символов
    if (sanitized.length > 20) {
      sanitized = sanitized.substring(0, 20);
    }

    return sanitized;
  }

  /// Валидирует формат username.
  ///
  /// Возвращает сообщение об ошибке или null если формат валиден.
  String? _validateFormat(String username) {
    // Проверка длины
    if (username.length < 3 || username.length > 20) {
      return 'Username должен содержать от 3 до 20 символов';
    }

    // Проверка символов
    if (!RegExp(r'^[a-zA-Z_][a-zA-Z0-9_]*$').hasMatch(username)) {
      return 'Username должен содержать только буквы, цифры и подчёркивание, '
          'и не может начинаться с цифры';
    }

    // Проверка что не состоит только из цифр
    if (RegExp(r'^\d+$').hasMatch(username)) {
      return 'Username не может состоять только из цифр';
    }

    return null;
  }
}
