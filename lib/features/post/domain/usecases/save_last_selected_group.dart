import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../repositories/group_memory_repository.dart';

/// Use case для сохранения ID последней выбранной группы.
///
/// Вызывается после успешной публикации поста для запоминания выбора группы.
@lazySingleton
class SaveLastSelectedGroup {
  const SaveLastSelectedGroup(this._repository);

  final GroupMemoryRepository _repository;

  /// Сохранить ID выбранной группы.
  ///
  /// [groupId] — ID группы, в которую был опубликован пост.
  ResultFuture<void> call(String groupId) {
    return _repository.saveLastSelectedGroup(groupId);
  }
}
