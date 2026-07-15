import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/repositories/follow_repository.dart';
import '../datasources/follow_remote_data_source.dart';

@LazySingleton(as: FollowRepository)
final class FollowRepositoryImpl implements FollowRepository {
  FollowRepositoryImpl(this._remote);

  final FollowRemoteDataSource _remote;

  @override
  ResultFuture<void> follow({
    required String followerId,
    required String targetUserId,
  }) async {
    try {
      await _remote.follow(followerId: followerId, targetUserId: targetUserId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> unfollow({
    required String followerId,
    required String targetUserId,
  }) async {
    try {
      await _remote.unfollow(
        followerId: followerId,
        targetUserId: targetUserId,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<bool> watchIsFollowing({
    required String followerId,
    required String targetUserId,
  }) async* {
    try {
      await for (final f in _remote.watchIsFollowing(
        followerId: followerId,
        targetUserId: targetUserId,
      )) {
        yield Right<Failure, bool>(f);
      }
    } on ServerException catch (e) {
      yield Left<Failure, bool>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, bool>(ServerFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<List<String>> getFollowingIds(String followerId) async {
    try {
      return Right(await _remote.getFollowingIds(followerId));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
