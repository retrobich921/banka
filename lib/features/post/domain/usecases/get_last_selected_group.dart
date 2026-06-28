import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/group_memory_repository.dart';

/// Use case для получения ID последней выбранной группы.
///
/// Используется при инициализации экрана создания поста для автоматического
/// выбора группы, в которую пользователь публиковал последний раз.
@lazySingleton
class GetLastSelectedGroup {
  const GetLastSelectedGroup(this._repository);

  final GroupMemoryRepository _repository;

  /// Получить ID последней выбранной группы.
  ///
  /// Возвращает `null`, если группа ещё не была сохранена.
  ResultFuture<String?> call() {
    return _repository.getLastSelectedGroup();
  }
}
