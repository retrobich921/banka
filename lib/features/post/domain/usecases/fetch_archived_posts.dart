import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/post.dart';
import '../repositories/post_repository.dart';

/// Архив пользователя: его посты, скрытые из лент (archived == true).
@lazySingleton
class FetchArchivedPosts implements UseCase<List<Post>, String> {
  const FetchArchivedPosts(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<List<Post>> call(String authorId) =>
      _repository.archivedPosts(authorId: authorId);
}
