import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/group_memory_repository.dart';

/// Use case для очистки сохранённого ID последней выбранной группы.
///
/// Вызывается, если сохранённая группа больше не существует
/// или пользователь не является её членом.
@lazySingleton
class ClearLastSelectedGroup {
  const ClearLastSelectedGroup(this._repository);

  final GroupMemoryRepository _repository;

  /// Очистить сохранённую группу.
  ResultFuture<void> call() {
    return _repository.clearLastSelectedGroup();
  }
}
