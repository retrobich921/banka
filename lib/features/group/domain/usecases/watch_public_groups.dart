import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/group.dart';
import '../repositories/group_repository.dart';

@lazySingleton
class WatchPublicGroups
    implements StreamResultUseCase<List<Group>, WatchPublicGroupsParams> {
  const WatchPublicGroups(this._repository);

  final GroupRepository _repository;

  @override
  ResultStream<List<Group>> call(WatchPublicGroupsParams params) =>
      _repository.watchPublicGroups(
        limit: params.limit,
        startAfterId: params.startAfterId,
      );
}

class WatchPublicGroupsParams extends Equatable {
  const WatchPublicGroupsParams({this.limit = 20, this.startAfterId});

  final int limit;
  final String? startAfterId;

  @override
  List<Object?> get props => [limit, startAfterId];
}
