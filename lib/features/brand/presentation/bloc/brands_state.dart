part of 'brands_bloc.dart';

enum BrandsStatus { initial, loading, ready, error }

final class BrandsState extends Equatable {
  const BrandsState({
    this.status = BrandsStatus.initial,
    this.brands = const [],
    this.errorMessage,
  });

  const BrandsState.initial() : this();

  final BrandsStatus status;
  final List<Brand> brands;
  final String? errorMessage;

  bool get isReady => status == BrandsStatus.ready;
  bool get isLoading => status == BrandsStatus.loading;
  bool get hasError => status == BrandsStatus.error;

  BrandsState copyWith({
    BrandsStatus? status,
    List<Brand>? brands,
    String? errorMessage,
    bool clearError = false,
  }) {
    return BrandsState(
      status: status ?? this.status,
      brands: brands ?? this.brands,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [status, brands, errorMessage];
}
