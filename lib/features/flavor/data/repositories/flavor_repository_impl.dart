import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/flavor.dart';
import '../../domain/repositories/flavor_repository.dart';
import '../datasources/flavor_remote_data_source.dart';

@LazySingleton(as: FlavorRepository)
final class FlavorRepositoryImpl implements FlavorRepository {
  FlavorRepositoryImpl(this._remote);

  final FlavorRemoteDataSource _remote;

  @override
  ResultStream<List<Flavor>> watchFlavors(String brandId) async* {
    try {
      await for (final flavors in _remote.watchFlavors(brandId)) {
        yield Right<Failure, List<Flavor>>(flavors);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Flavor>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Flavor>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultFuture<Flavor> createFlavor({
    required String brandId,
    required String name,
  }) async {
    try {
      final flavor = await _remote.createFlavor(brandId: brandId, name: name);
      return Right(flavor);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
