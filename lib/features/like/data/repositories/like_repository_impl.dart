import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/like.dart';
import '../../domain/repositories/like_repository.dart';
import '../datasources/like_remote_data_source.dart';

@LazySingleton(as: LikeRepository)
final class LikeRepositoryImpl implements LikeRepository {
  LikeRepositoryImpl(this._remote);

  final LikeRemoteDataSource _remote;

  @override
  ResultFuture<void> likePost({
    required String postId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
  }) async {
    try {
      await _remote.likePost(
        postId: postId,
        userId: userId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> unlikePost({
    required String postId,
    required String userId,
  }) async {
    try {
      await _remote.unlikePost(postId: postId, userId: userId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<bool> watchHasLiked({
    required String postId,
    required String userId,
  }) async* {
    try {
      await for (final has in _remote.watchHasLiked(
        postId: postId,
        userId: userId,
      )) {
        yield Right<Failure, bool>(has);
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
  ResultStream<List<Like>> watchLikers(String postId) async* {
    try {
      await for (final likes in _remote.watchLikers(postId)) {
        yield Right<Failure, List<Like>>(likes);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Like>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Like>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }
}
