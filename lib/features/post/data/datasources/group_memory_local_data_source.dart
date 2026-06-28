import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Контракт локального источника для хранения последней выбранной группы.
/// Используется для автоматического выбора группы при создании поста.
abstract interface class GroupMemoryLocalDataSource {
  /// Получить ID последней выбранной группы.
  /// Возвращает `null`, если группа не была сохранена.
  Future<String?> getLastSelectedGroup();

  /// Сохранить ID последней выбранной группы.
  Future<void> saveLastSelectedGroup(String groupId);

  /// Очистить сохранённую группу.
  Future<void> clearLastSelectedGroup();
}

/// Реализация [GroupMemoryLocalDataSource] через SharedPreferences.
///
/// Хранит ID последней выбранной группы локально на устройстве.
/// Используется для автоматического выбора группы при создании поста.
@LazySingleton(as: GroupMemoryLocalDataSource)
class SharedPrefsGroupMemoryDataSource
    implements GroupMemoryLocalDataSource {
  const SharedPrefsGroupMemoryDataSource(this._prefs);

  final SharedPreferences _prefs;

  /// Ключ для хранения ID последней выбранной группы
  static const String _key = 'last_selected_group_id';

  @override
  Future<String?> getLastSelectedGroup() async {
    return _prefs.getString(_key);
  }

  @override
  Future<void> saveLastSelectedGroup(String groupId) async {
    await _prefs.setString(_key, groupId);
  }

  @override
  Future<void> clearLastSelectedGroup() async {
    await _prefs.remove(_key);
  }
}
