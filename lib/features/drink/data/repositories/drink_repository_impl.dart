import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../post/domain/entities/post.dart';
import '../../domain/entities/drink.dart';
import '../../domain/repositories/drink_repository.dart';
import '../datasources/drink_remote_data_source.dart';

@LazySingleton(as: DrinkRepository)
final class DrinkRepositoryImpl implements DrinkRepository {
  DrinkRepositoryImpl(this._remote);

  final DrinkRemoteDataSource _remote;

  @override
  ResultStream<Drink?> watchDrink(String drinkId) async* {
    try {
      await for (final drink in _remote.watchDrink(drinkId)) {
        yield Right<Failure, Drink?>(drink);
      }
    } on ServerException catch (e) {
      yield Left<Failure, Drink?>(
        ServerFailure(message: e.message, cause: e.cause),
      );
    } catch (e) {
      yield Left<Failure, Drink?>(
        ServerFailure(message: e.toString(), cause: e),
      );
    }
  }

  @override
  ResultFuture<List<Drink>> topDrinks({int limit = 100}) async {
    try {
      return Right(await _remote.fetchTopDrinks(limit: limit));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }

  @override
  ResultFuture<List<Post>> drinkPosts({
    required String drinkId,
    int limit = 50,
  }) async {
    try {
      return Right(
        await _remote.fetchDrinkPosts(drinkId: drinkId, limit: limit),
      );
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, cause: e.cause));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString(), cause: e));
    }
  }
}
