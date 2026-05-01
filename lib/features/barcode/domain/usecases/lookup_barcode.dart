import 'package:injectable/injectable.dart';

import '../../../../core/utils/typedefs.dart';
import '../entities/barcode.dart';
import '../repositories/barcode_repository.dart';

/// Поиск штрих-кода в коллективной базе.
///
/// Возвращает `Right(null)`, если документа нет (это не ошибка — это
/// сигнал «новая банка, предложи пользователю сохранить»).
@lazySingleton
class LookupBarcode {
  const LookupBarcode(this._repository);

  final BarcodeRepository _repository;

  ResultFuture<Barcode?> call(String code) => _repository.lookupBarcode(code);
}
