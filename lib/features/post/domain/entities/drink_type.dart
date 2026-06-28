/// Тип напитка для поста-«банки».
///
/// Приложение про любые напитки, а не только энергетики, поэтому у каждой
/// банки есть категория. `storageKey` — стабильный ключ для Firestore (не
/// зависит от локализации), `label` — русское название для UI.
///
/// Для существующих/несохранённых документов (поле отсутствует) считаем тип
/// `energy` — исторически каталог был про энергетики.
///
/// TODO(types): список временный и будет расширен — см. память проекта
/// `taste-rating-rework` / `drink-types-taxonomy` (полная классификация
/// напитков).
enum DrinkType {
  energy('energy', 'Энергетик'),
  soda('soda', 'Газировка'),
  juice('juice', 'Сок'),
  water('water', 'Вода'),
  teaCoffee('tea_coffee', 'Чай / кофе'),
  other('other', 'Другое');

  const DrinkType(this.storageKey, this.label);

  final String storageKey;
  final String label;

  /// Разбор значения из Firestore. Неизвестный/`null` ключ → `energy`.
  static DrinkType fromKey(String? key) {
    // Легаси: раньше был отдельный «Лимонад» — теперь это «Газировка».
    if (key == 'lemonade') return DrinkType.soda;
    for (final type in DrinkType.values) {
      if (type.storageKey == key) return type;
    }
    return DrinkType.energy;
  }
}
