import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class GetPost implements UseCase<Post?, String> {
  const GetPost(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<Post?> call(String params) => _repository.getPost(params);
}
