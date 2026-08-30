import 'package:freezed_annotation/freezed_annotation.dart';

part 'drink_spec.freezed.dart';

/// Характеристики напитка, которые не выводятся из фото: крепость, стиль,
/// тара, объём. Сейчас заполняются для пива — у безалкогольных банок эти
/// поля пустые, и блок в UI не показывается.
///
/// Все поля опциональные: старые посты живут без `spec`, а пользователь
/// может не знать IBU. `DrinkSpec.isEmpty` — признак «ничего не указали».
@freezed
sealed class DrinkSpec with _$DrinkSpec {
  const DrinkSpec._();

  const factory DrinkSpec({
    /// Крепость, % об.
    double? abv,
    BeerStyle? style,
    DrinkContainer? container,

    /// Объём порции, мл.
    int? volumeMl,

    /// Горечь по шкале IBU — необязательная деталь для любителей.
    int? ibu,
  }) = _DrinkSpec;

  bool get isEmpty =>
      abv == null &&
      style == null &&
      container == null &&
      volumeMl == null &&
      ibu == null;

  bool get isNotEmpty => !isEmpty;

  /// Короткая строка для чипа в ленте: «5,4% · IPA».
  String get shortLabel => [
    if (abv != null) '${_formatAbv(abv!)}%',
    if (style != null) style!.label,
  ].join(' · ');

  static String _formatAbv(double value) {
    final rounded = (value * 10).round() / 10;
    final text = rounded.toStringAsFixed(rounded % 1 == 0 ? 0 : 1);
    return text.replaceAll('.', ',');
  }
}

/// Стиль пива. Список фиксированный: справочник в Firestore здесь избыточен,
/// а строковый ключ позволяет позже переехать на коллективную коллекцию без
/// миграции данных.
enum BeerStyle {
  lager('lager', 'Лагер'),
  pilsner('pilsner', 'Пилснер'),
  wheat('wheat', 'Пшеничное'),
  ipa('ipa', 'IPA'),
  apa('apa', 'APA / пейл-эль'),
  neipa('neipa', 'NEIPA'),
  ale('ale', 'Эль'),
  stout('stout', 'Стаут'),
  porter('porter', 'Портер'),
  sour('sour', 'Кислый / сауэр'),
  lambic('lambic', 'Ламбик'),
  bock('bock', 'Бок'),
  amber('amber', 'Красное / амбер'),
  nonAlcoholic('non_alcoholic', 'Безалкогольное'),
  other('other', 'Другое');

  const BeerStyle(this.storageKey, this.label);

  final String storageKey;
  final String label;

  /// Неизвестный ключ → `other` (совместимость со старыми документами и
  /// будущим расширением списка).
  static BeerStyle? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final style in BeerStyle.values) {
      if (style.storageKey == key) return style;
    }
    return BeerStyle.other;
  }
}

/// Тара, в которой напиток куплен.
enum DrinkContainer {
  can('can', 'Банка'),
  bottle('bottle', 'Бутылка'),
  draft('draft', 'Розлив');

  const DrinkContainer(this.storageKey, this.label);

  final String storageKey;
  final String label;

  static DrinkContainer? fromKey(String? key) {
    if (key == null || key.isEmpty) return null;
    for (final container in DrinkContainer.values) {
      if (container.storageKey == key) return container;
    }
    return null;
  }
}
