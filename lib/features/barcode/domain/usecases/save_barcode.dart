import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/barcode.dart';
import '../repositories/barcode_repository.dart';

/// Contribute-back: сохранить штрих-код, отсканированный пользователем.
///
/// Вызывается из `CreatePostBloc` после успешного создания поста, если
/// `state.barcode` непустой и в базе ещё нет записи. Использует merge,
/// поэтому ошибка прав доступа невозможна для существующего документа,
/// и операция идемпотентна.
@lazySingleton
class SaveBarcode {
  const SaveBarcode(this._repository);

  final BarcodeRepository _repository;

  ResultFuture<Barcode> call(SaveBarcodeParams params) {
    return _repository.saveBarcode(
      code: params.code,
      drinkName: params.drinkName,
      contributedBy: params.contributedBy,
      brandId: params.brandId,
      brandName: params.brandName,
      suggestedPhotoUrl: params.suggestedPhotoUrl,
    );
  }
}

class SaveBarcodeParams extends Equatable {
  const SaveBarcodeParams({
    required this.code,
    required this.drinkName,
    required this.contributedBy,
    this.brandId,
    this.brandName,
    this.suggestedPhotoUrl,
  });

  final String code;
  final String drinkName;
  final String contributedBy;
  final String? brandId;
  final String? brandName;
  final String? suggestedPhotoUrl;

  @override
  List<Object?> get props => [
    code,
    drinkName,
    contributedBy,
    brandId,
    brandName,
    suggestedPhotoUrl,
  ];
}
