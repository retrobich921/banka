import 'package:equatable/equatable.dart';

/// Набор фильтров для поиска постов.
///
/// Все поля опциональные — `null` означает «не фильтровать». Sprint 13
/// добавит селектор бренда (пока — id строкой).
final class SearchFilters extends Equatable {
  const SearchFilters({this.brandId, this.groupId});

  const SearchFilters.empty() : this();

  final String? brandId;
  final String? groupId;

  /// `true`, если хотя бы один фильтр применён.
  bool get hasAny => brandId != null || groupId != null;

  SearchFilters copyWith({
    String? brandId,
    String? groupId,
    bool clearBrand = false,
    bool clearGroup = false,
  }) {
    return SearchFilters(
      brandId: clearBrand ? null : (brandId ?? this.brandId),
      groupId: clearGroup ? null : (groupId ?? this.groupId),
    );
  }

  @override
  List<Object?> get props => [brandId, groupId];
}
