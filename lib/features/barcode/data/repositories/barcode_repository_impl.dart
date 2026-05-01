import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../domain/entities/barcode.dart';
import '../../domain/repositories/barcode_repository.dart';
import '../datasources/barcode_remote_data_source.dart';

@LazySingleton(as: BarcodeRepository)
final class BarcodeRepositoryImpl implements BarcodeRepository {
  BarcodeRepositoryImpl(this._remote);

  final BarcodeRemoteDataSource _remote;

  @override
  ResultFuture<Barcode?> lookupBarcode(String code) async {
    try {
      final barcode = await _remote.lookupBarcode(code);
      return Right(barcode);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<Barcode> saveBarcode({
    required String code,
    required String drinkName,
    required String contributedBy,
    String? brandId,
    String? brandName,
    String? suggestedPhotoUrl,
  }) async {
    try {
      final barcode = await _remote.saveBarcode(
        code: code,
        drinkName: drinkName,
        contributedBy: contributedBy,
        brandId: brandId,
        brandName: brandName,
        suggestedPhotoUrl: suggestedPhotoUrl,
      );
      return Right(barcode);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
