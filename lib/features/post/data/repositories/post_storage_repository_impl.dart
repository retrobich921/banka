import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/post.dart';
import '../../domain/repositories/post_storage_repository.dart';
import '../datasources/post_image_data_source.dart';

@LazySingleton(as: PostStorageRepository)
final class PostStorageRepositoryImpl implements PostStorageRepository {
  PostStorageRepositoryImpl(this._dataSource);

  final PostImageDataSource _dataSource;

  @override
  ResultFuture<PostPhoto> uploadPostImage({
    required String postId,
    required int index,
    required File file,
  }) async {
    try {
      final photo = await _dataSource.uploadPostImage(
        postId: postId,
        index: index,
        file: file,
      );
      return Right(photo);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
