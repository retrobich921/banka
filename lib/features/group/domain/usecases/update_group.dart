import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class UpdateGroup implements UseCase<void, UpdateGroupParams> {
  const UpdateGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<void> call(UpdateGroupParams params) {
    return _repository.updateGroup(
      groupId: params.groupId,
      name: params.name,
      description: params.description,
      isPublic: params.isPublic,
      coverUrl: params.coverUrl,
      tags: params.tags,
    );
  }
}

class UpdateGroupParams extends Equatable {
  const UpdateGroupParams({
    required this.groupId,
    this.name,
    this.description,
    this.isPublic,
    this.coverUrl,
    this.tags,
  });

  final String groupId;
  final String? name;
  final String? description;
  final bool? isPublic;
  final String? coverUrl;
  final List<String>? tags;

  @override
  List<Object?> get props => [
    groupId,
    name,
    description,
    isPublic,
    coverUrl,
    tags,
  ];
}
