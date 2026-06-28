import 'package:freezed_annotation/freezed_annotation.dart';

part 'flavor.freezed.dart';

/// Вкус напитка, привязанный к конкретному бренду.
///
/// Документ: `brands/{brandId}/flavors/{flavorId}`
/// Каждый бренд имеет свой набор вкусов.
@freezed
sealed class Flavor with _$Flavor {
  const factory Flavor({
    required String id,
    required String brandId,
    required String name,
    DateTime? createdAt,
  }) = _Flavor;
}
