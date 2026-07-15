import '../../../../core/utils/typedefs.dart';
import '../../../post/domain/entities/post.dart';
import '../entities/drink.dart';

/// Чтение карточек напитков. Запись (денорм-агрегаты) делает пост-слой
/// атомарно с созданием/удалением поста.
abstract interface class DrinkRepository {
  ResultStream<Drink?> watchDrink(String drinkId);

  ResultFuture<List<Drink>> topDrinks({int limit = 500});

  ResultFuture<List<Post>> drinkPosts({
    required String drinkId,
    int limit = 50,
  });
}
