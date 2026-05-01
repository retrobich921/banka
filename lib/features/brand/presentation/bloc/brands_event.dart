part of 'brands_bloc.dart';

sealed class BrandsEvent extends Equatable {
  const BrandsEvent();

  @override
  List<Object?> get props => [];
}

final class BrandsSubscribeRequested extends BrandsEvent {
  const BrandsSubscribeRequested();
}

final class BrandsResetRequested extends BrandsEvent {
  const BrandsResetRequested();
}

/// Внутренний event — стрим выкинул новый снэпшот.
final class _BrandsReceived extends BrandsEvent {
  const _BrandsReceived(this.result);

  final Either<Failure, List<Brand>> result;

  @override
  List<Object?> get props => [result];
}
