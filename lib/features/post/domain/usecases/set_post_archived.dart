import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/post_repository.dart';

/// Архивировать (archived=true) или вернуть из архива (archived=false) пост.
@lazySingleton
class SetPostArchived implements UseCase<void, SetPostArchivedParams> {
  const SetPostArchived(this._repository);

  final PostRepository _repository;

  @override
  ResultFuture<void> call(SetPostArchivedParams params) =>
      _repository.setArchived(postId: params.postId, archived: params.archived);
}

final class SetPostArchivedParams extends Equatable {
  const SetPostArchivedParams({required this.postId, required this.archived});

  final String postId;
  final bool archived;

  @override
  List<Object?> get props => [postId, archived];
}
