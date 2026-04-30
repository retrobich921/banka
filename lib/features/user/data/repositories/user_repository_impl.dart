import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/user_profile.dart';
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
}
