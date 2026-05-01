import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/brand.dart';
import '../repositories/brand_repository.dart';

@lazySingleton
class WatchBrand {
  const WatchBrand(this._repository);

  final BrandRepository _repository;

  ResultStream<Brand?> call(String brandId) => _repository.watchBrand(brandId);
}
