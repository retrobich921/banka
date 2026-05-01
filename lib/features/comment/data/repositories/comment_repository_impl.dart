import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/comment.dart';
import '../../domain/repositories/comment_repository.dart';
import '../datasources/comment_remote_data_source.dart';

@LazySingleton(as: CommentRepository)
final class CommentRepositoryImpl implements CommentRepository {
  CommentRepositoryImpl(this._remote);

  final CommentRemoteDataSource _remote;

  @override
  ResultFuture<String> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorPhotoUrl,
    required String text,
  }) async {
    try {
      final id = await _remote.addComment(
        postId: postId,
        authorId: authorId,
        authorName: authorName,
        authorPhotoUrl: authorPhotoUrl,
        text: text,
      );
      return Right(id);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<void> deleteComment({
    required String postId,
    required String commentId,
  }) async {
    try {
      await _remote.deleteComment(postId: postId, commentId: commentId);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultStream<List<Comment>> watchComments(String postId) async* {
    try {
      await for (final comments in _remote.watchComments(postId)) {
        yield Right<Failure, List<Comment>>(comments);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Comment>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Comment>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }
}
