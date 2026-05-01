import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/brand.dart';
import '../../domain/usecases/watch_brands.dart';

part 'brands_event.dart';
part 'brands_state.dart';

/// BLoC для списка брендов (`brands/{}` отсортированных по
/// `postsCount desc, name asc`).
///
/// Используется одинаково на `BrandsPage` и в `BrandPickerSheet` — в
/// обоих местах нужен один и тот же реактивный список.
@injectable
class BrandsBloc extends Bloc<BrandsEvent, BrandsState> {
  BrandsBloc(this._watchBrands) : super(const BrandsState.initial()) {
    on<BrandsSubscribeRequested>(_onSubscribe);
    on<_BrandsReceived>(_onReceived);
    on<BrandsResetRequested>(_onReset);
  }

  final WatchBrands _watchBrands;

  StreamSubscription<Either<Failure, List<Brand>>>? _sub;

  Future<void> _onSubscribe(
    BrandsSubscribeRequested event,
    Emitter<BrandsState> emit,
  ) async {
    if (_sub != null) return;
    emit(state.copyWith(status: BrandsStatus.loading, clearError: true));
    _sub = _watchBrands().listen((r) => add(_BrandsReceived(r)));
  }

  void _onReceived(_BrandsReceived event, Emitter<BrandsState> emit) {
    event.result.fold(
      (failure) => emit(
        state.copyWith(
          status: BrandsStatus.error,
          errorMessage: failure.message ?? 'Не удалось загрузить бренды',
        ),
      ),
      (brands) => emit(
        state.copyWith(
          status: BrandsStatus.ready,
          brands: brands,
          clearError: true,
        ),
      ),
    );
  }

  Future<void> _onReset(
    BrandsResetRequested event,
    Emitter<BrandsState> emit,
  ) async {
    await _sub?.cancel();
    _sub = null;
    emit(const BrandsState.initial());
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
