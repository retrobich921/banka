import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/brand.dart';
import '../repositories/brand_repository.dart';

/// Идемпотентное создание бренда — возвращает существующий, если уже
/// есть документ с таким `slug`. Используется в `CreatePostPage`, где
/// пользователь ввёл строку с брендом, которой ещё нет в базе.
@lazySingleton
class EnsureBrand {
  const EnsureBrand(this._repository);

  final BrandRepository _repository;

  ResultFuture<Brand> call(EnsureBrandParams params) {
    return _repository.ensureBrand(
      name: params.name,
      country: params.country,
      logoUrl: params.logoUrl,
    );
  }
}

class EnsureBrandParams extends Equatable {
  const EnsureBrandParams({required this.name, this.country, this.logoUrl});

  final String name;
  final String? country;
  final String? logoUrl;

  @override
  List<Object?> get props => [name, country, logoUrl];
}
