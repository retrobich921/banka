import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_storage_repository.dart';

@lazySingleton
class UploadPostImage implements UseCase<PostPhoto, UploadPostImageParams> {
  const UploadPostImage(this._repository);

  final PostStorageRepository _repository;

  @override
  ResultFuture<PostPhoto> call(UploadPostImageParams params) {
    return _repository.uploadPostImage(
      postId: params.postId,
      index: params.index,
      file: params.file,
    );
  }
}

class UploadPostImageParams extends Equatable {
  const UploadPostImageParams({
    required this.postId,
    required this.index,
    required this.file,
  });

  final String postId;
  final int index;
  final File file;

  @override
  List<Object?> get props => [postId, index, file.path];
}
