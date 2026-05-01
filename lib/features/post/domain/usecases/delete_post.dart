import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/post_repository.dart';

@lazySingleton
class DeletePost implements UseCase<void, String> {
  const DeletePost(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<void> call(String params) => _repository.deletePost(params);
}
