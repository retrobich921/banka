import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/brand.dart';
import '../../domain/repositories/brand_repository.dart';
import '../datasources/brand_remote_data_source.dart';

@LazySingleton(as: BrandRepository)
final class BrandRepositoryImpl implements BrandRepository {
  BrandRepositoryImpl(this._remote);

  final BrandRemoteDataSource _remote;

  @override
  ResultStream<List<Brand>> watchBrands() async* {
    try {
      await for (final brands in _remote.watchBrands()) {
        yield Right<Failure, List<Brand>>(brands);
      }
    } on ServerException catch (e) {
      yield Left<Failure, List<Brand>>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, List<Brand>>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultStream<Brand?> watchBrand(String brandId) async* {
    try {
      await for (final brand in _remote.watchBrand(brandId)) {
        yield Right<Failure, Brand?>(brand);
      }
    } on ServerException catch (e) {
      yield Left<Failure, Brand?>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, Brand?>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultFuture<Brand> ensureBrand({
    required String name,
    String? country,
    String? logoUrl,
  }) async {
    try {
      final brand = await _remote.ensureBrand(
        name: name,
        country: country,
        logoUrl: logoUrl,
      );
      return Right(brand);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
