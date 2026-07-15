import 'package:injectable/injectable.dart';

import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';
import '../../../post/domain/entities/post.dart';
import '../entities/drink.dart';
import '../repositories/drink_repository.dart';

/// Live-подписка на карточку напитка.
@lazySingleton
class WatchDrink implements StreamResultUseCase<Drink?, String> {
  const WatchDrink(this._repository);

  final DrinkRepository _repository;

  @override
  ResultStream<Drink?> call(String drinkId) => _repository.watchDrink(drinkId);
}

/// Топ напитков для раздела «Топы» (сортировка по средней оценке —
/// на клиенте, см. datasource).
@lazySingleton
class FetchTopDrinks implements UseCase<List<Drink>, NoParams> {
  const FetchTopDrinks(this._repository);

  final DrinkRepository _repository;

  @override
  ResultFuture<List<Drink>> call(NoParams params) => _repository.topDrinks();
}

/// Посты-«рецензии» конкретного напитка.
@lazySingleton
class FetchDrinkPosts implements UseCase<List<Post>, String> {
  const FetchDrinkPosts(this._repository);

  final DrinkRepository _repository;

  @override
  ResultFuture<List<Post>> call(String drinkId) =>
      _repository.drinkPosts(drinkId: drinkId);
}
