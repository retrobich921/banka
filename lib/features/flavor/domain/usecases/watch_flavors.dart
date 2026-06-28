import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../entities/flavor.dart';
import '../repositories/flavor_repository.dart';

@lazySingleton
class WatchFlavors implements StreamResultUseCase<List<Flavor>, String> {
  const WatchFlavors(this._repository);

  final FlavorRepository _repository;

  @override
  ResultStream<List<Flavor>> call(String params) =>
      _repository.watchFlavors(params);
}
