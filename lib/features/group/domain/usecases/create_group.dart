import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class CreateGroup implements UseCase<Group, CreateGroupParams> {
  const CreateGroup(this._repository);

  final GroupRepository _repository;

  @override
  ResultFuture<Group> call(CreateGroupParams params) {
    return _repository.createGroup(
      ownerId: params.ownerId,
      name: params.name,
      description: params.description,
      isPublic: params.isPublic,
      tags: params.tags,
      coverUrl: params.coverUrl,
    );
  }
}

class CreateGroupParams extends Equatable {
  const CreateGroupParams({
    required this.ownerId,
    required this.name,
    this.description = '',
    this.isPublic = true,
    this.tags = const <String>[],
    this.coverUrl,
  });

  final String ownerId;
  final String name;
  final String description;
  final bool isPublic;
  final List<String> tags;
  final String? coverUrl;

  @override
  List<Object?> get props => [
    ownerId,
    name,
    description,
    isPublic,
    tags,
    coverUrl,
  ];
}
