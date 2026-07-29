/// Ачивки коллекционера.
///
/// Система расширяемая: ачивка = условие над данными профиля. Пока все
/// базовые считаются от размера коллекции (`stats.cansCount`), поэтому
/// ничего не пишем в Firestore — статус выводится на клиенте. Когда
/// появятся «серверные» ачивки (первый сок, лимитка и т.п.), сюда
/// добавится чекер по постам.
class Achievement {
  const Achievement({
    required this.id,
    required this.title,
    required this.emoji,
    required this.threshold,
  });

  final String id;
  final String title;
  final String emoji;

  /// Нужное число банок в коллекции.
  final int threshold;

  bool earnedBy(int cansCount) => cansCount >= threshold;
}

/// Базовый набор: вехи размера коллекции.
const List<Achievement> kCollectionAchievements = [
  Achievement(id: 'cans1', title: 'Первая банка', emoji: '🥤', threshold: 1),
  Achievement(id: 'cans10', title: 'Десятка', emoji: '🔟', threshold: 10),
  Achievement(id: 'cans25', title: 'Полка растёт', emoji: '📦', threshold: 25),
  Achievement(id: 'cans50', title: 'Полтинник', emoji: '🥉', threshold: 50),
  Achievement(id: 'cans100', title: 'Сотка', emoji: '🥈', threshold: 100),
  Achievement(id: 'cans150', title: 'Полторашка', emoji: '🥇', threshold: 150),
  Achievement(id: 'cans200', title: 'Две сотни', emoji: '💎', threshold: 200),
  Achievement(id: 'cans250', title: 'Четвертак', emoji: '👑', threshold: 250),
  Achievement(
    id: 'cans300',
    title: 'Легенда полки',
    emoji: '🏆',
    threshold: 300,
  ),
];

/// Полученные ачивки — от самой «дорогой» к простой.
List<Achievement> earnedAchievements(int cansCount) => [
  for (final a in kCollectionAchievements.reversed)
    if (a.earnedBy(cansCount)) a,
];

/// Ближайшая невыполненная цель. `null` — собраны все.
Achievement? nextAchievement(int cansCount) {
  for (final a in kCollectionAchievements) {
    if (!a.earnedBy(cansCount)) return a;
  }
  return null;
}

/// Прогресс к ближайшей цели в долях единицы: считается от порога
/// предыдущей ачивки, чтобы полоска не «зависала» почти полной надолго.
/// Само значение порога в UI не показываем — только ближайшую цель.
double nextAchievementProgress(int cansCount) {
  final next = nextAchievement(cansCount);
  if (next == null) return 1;
  var previousThreshold = 0;
  for (final a in kCollectionAchievements) {
    if (a.id == next.id) break;
    previousThreshold = a.threshold;
  }
  final span = next.threshold - previousThreshold;
  if (span <= 0) return 1;
  final done = (cansCount - previousThreshold) / span;
  return done.clamp(0, 1).toDouble();
}

/// Ачивки, которые показываем в шапке профиля: выбранные пользователем
/// (и всё ещё полученные), иначе — последние полученные.
List<Achievement> visibleAchievements({
  required int cansCount,
  required List<String> pinnedIds,
  int limit = 3,
}) {
  final earned = earnedAchievements(cansCount);
  if (pinnedIds.isEmpty) return earned.take(limit).toList(growable: false);
  final pinned = [
    for (final a in earned)
      if (pinnedIds.contains(a.id)) a,
  ];
  return pinned.isEmpty
      ? earned.take(limit).toList(growable: false)
      : pinned.take(limit).toList(growable: false);
}
