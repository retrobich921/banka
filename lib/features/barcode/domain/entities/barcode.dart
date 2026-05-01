import 'package:freezed_annotation/freezed_annotation.dart';

part 'barcode.freezed.dart';

/// Запись коллективной базы штрих-кодов (`barcodes/{ean}`).
///
/// `id` — это сам EAN-13 / UPC код (используем как documentId, чтобы
/// `lookupBarcode` был один точечный `get` без запроса). Поля
/// `drinkName` и `brandId/brandName` — кешированные данные банки,
/// которые подставляются в форму создания поста; `suggestedPhotoUrl` —
/// фото первой банки, которая «зарегистрировала» этот штрих-код,
/// используется как дефолтное превью. `contributedBy` — uid того, кто
/// первый внёс запись.
@freezed
sealed class Barcode with _$Barcode {
  const factory Barcode({
    required String id,
    required String drinkName,
    String? brandId,
    String? brandName,
    String? suggestedPhotoUrl,
    String? contributedBy,
    DateTime? createdAt,
  }) = _Barcode;
}
