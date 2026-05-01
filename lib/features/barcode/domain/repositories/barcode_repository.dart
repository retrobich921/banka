import '../../../../core/utils/typedefs.dart';
import '../entities/barcode.dart';

/// Контракт коллективной базы штрих-кодов (`barcodes/{ean}`).
///
/// Классическая структура «look-up если есть, contribute если нет».
/// Запись делается идемпотентно (set с merge), чтобы повторный вклад
/// от другого пользователя не затёр чужие данные неожиданно (в Sprint 18
/// это можно ужесточить: разрешать только обновление пустых полей).
abstract interface class BarcodeRepository {
  /// Точечный `get` по `code` (EAN-13/UPC). Возвращает `null`, если
  /// запись отсутствует — тогда UI предложит сохранить текущие данные
  /// банки.
  ResultFuture<Barcode?> lookupBarcode(String code);

  /// Сохраняет штрих-код в коллективной базе. Идемпотентный set с
  /// merge — повторная отправка от другого пользователя не сломает
  /// существующий документ, но и не перезапишет `contributedBy`.
  ResultFuture<Barcode> saveBarcode({
    required String code,
    required String drinkName,
    required String contributedBy,
    String? brandId,
    String? brandName,
    String? suggestedPhotoUrl,
  });
}
