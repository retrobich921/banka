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
