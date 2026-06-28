import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/flavor.dart';
import '../repositories/flavor_repository.dart';

@lazySingleton
class CreateFlavor implements UseCase<Flavor, CreateFlavorParams> {
  const CreateFlavor(this._repository);

  final FlavorRepository _repository;

  @override
  ResultFuture<Flavor> call(CreateFlavorParams params) =>
      _repository.createFlavor(brandId: params.brandId, name: params.name);
}

class CreateFlavorParams extends Equatable {
  const CreateFlavorParams({required this.brandId, required this.name});

  final String brandId;
  final String name;

  @override
  List<Object?> get props => [brandId, name];
}
