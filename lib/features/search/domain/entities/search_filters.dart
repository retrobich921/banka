import 'package:equatable/equatable.dart';

/// Набор фильтров для поиска постов.
///
/// Все поля опциональные — `null` означает «не фильтровать». Sprint 13
/// добавит селектор бренда (пока — id строкой).
final class SearchFilters extends Equatable {
  const SearchFilters({
    this.rarityMin,
    this.rarityMax,
    this.brandId,
    this.groupId,
  });

  const SearchFilters.empty() : this();

  final int? rarityMin;
  final int? rarityMax;
  final String? brandId;
  final String? groupId;

  /// `true`, если хотя бы один фильтр применён.
  bool get hasAny =>
      rarityMin != null ||
      rarityMax != null ||
      brandId != null ||
      groupId != null;

  SearchFilters copyWith({
    int? rarityMin,
    int? rarityMax,
    String? brandId,
    String? groupId,
    bool clearRarityMin = false,
    bool clearRarityMax = false,
    bool clearBrand = false,
    bool clearGroup = false,
  }) {
    return SearchFilters(
      rarityMin: clearRarityMin ? null : (rarityMin ?? this.rarityMin),
      rarityMax: clearRarityMax ? null : (rarityMax ?? this.rarityMax),
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      groupId: clearGroup ? null : (groupId ?? this.groupId),
    );
  }

  @override
  List<Object?> get props => [rarityMin, rarityMax, brandId, groupId];
}
