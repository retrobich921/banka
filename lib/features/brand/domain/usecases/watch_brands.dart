import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/brand.dart';
import '../repositories/brand_repository.dart';

@lazySingleton
class WatchBrands {
  const WatchBrands(this._repository);

  final BrandRepository _repository;

  ResultStream<List<Brand>> call() => _repository.watchBrands();
}
