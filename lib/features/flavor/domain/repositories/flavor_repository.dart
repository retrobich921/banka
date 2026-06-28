import '../../../../core/utils/typedefs.dart';
import '../entities/flavor.dart';

abstract interface class FlavorRepository {
  ResultStream<List<Flavor>> watchFlavors(String brandId);
  
  ResultFuture<Flavor> createFlavor({
    required String brandId,
    required String name,
  });
}
