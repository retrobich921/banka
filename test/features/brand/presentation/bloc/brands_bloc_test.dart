import 'package:banka/core/error/failures.dart';
import 'package:banka/features/brand/domain/entities/brand.dart';
import 'package:banka/features/brand/domain/usecases/watch_brands.dart';
import 'package:banka/features/brand/presentation/bloc/brands_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWatchBrands extends Mock implements WatchBrands {}

void main() {
  late _MockWatchBrands watchBrands;

  const brand = Brand(
    id: 'b-1',
    name: 'Monster',
    slug: 'monster',
    postsCount: 3,
  );

  setUp(() {
    watchBrands = _MockWatchBrands();
  });

  BrandsBloc buildBloc() => BrandsBloc(watchBrands);

  group('BrandsSubscribeRequested', () {
    blocTest<BrandsBloc, BrandsState>(
      'emits [loading, ready] on successful stream',
      setUp: () {
        when(
          () => watchBrands(),
        ).thenAnswer((_) => Stream.value(const Right(<Brand>[brand])));
      },
      build: buildBloc,
      act: (b) => b.add(const BrandsSubscribeRequested()),
      expect: () => [
        isA<BrandsState>().having(
          (s) => s.status,
          'status',
          BrandsStatus.loading,
        ),
        isA<BrandsState>()
            .having((s) => s.status, 'status', BrandsStatus.ready)
            .having((s) => s.brands.length, 'brands', 1)
            .having((s) => s.brands.first.id, 'first id', 'b-1'),
      ],
      verify: (_) {
        verify(() => watchBrands()).called(1);
      },
    );

    blocTest<BrandsBloc, BrandsState>(
      'emits error on Failure',
      setUp: () {
        when(() => watchBrands()).thenAnswer(
          (_) => Stream.value(const Left(ServerFailure(message: 'boom'))),
        );
      },
      build: buildBloc,
      act: (b) => b.add(const BrandsSubscribeRequested()),
      expect: () => [
        isA<BrandsState>().having(
          (s) => s.status,
          'status',
          BrandsStatus.loading,
        ),
        isA<BrandsState>()
            .having((s) => s.status, 'status', BrandsStatus.error)
            .having((s) => s.errorMessage, 'msg', 'boom'),
      ],
    );

    blocTest<BrandsBloc, BrandsState>(
      'second subscribe is a no-op (single subscription)',
      setUp: () {
        when(
          () => watchBrands(),
        ).thenAnswer((_) => Stream.value(const Right(<Brand>[brand])));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const BrandsSubscribeRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const BrandsSubscribeRequested());
      },
      verify: (_) {
        verify(() => watchBrands()).called(1);
      },
    );
  });

  group('BrandsResetRequested', () {
    blocTest<BrandsBloc, BrandsState>(
      'cancels subscription and returns to initial',
      setUp: () {
        when(
          () => watchBrands(),
        ).thenAnswer((_) => Stream.value(const Right(<Brand>[brand])));
      },
      build: buildBloc,
      act: (b) async {
        b.add(const BrandsSubscribeRequested());
        await Future<void>.delayed(Duration.zero);
        b.add(const BrandsResetRequested());
      },
      expect: () => [
        isA<BrandsState>().having(
          (s) => s.status,
          'status',
          BrandsStatus.loading,
        ),
        isA<BrandsState>()
            .having((s) => s.status, 'status', BrandsStatus.ready)
            .having((s) => s.brands.length, 'brands', 1),
        isA<BrandsState>().having(
          (s) => s.status,
          'status',
          BrandsStatus.initial,
        ),
      ],
    );
  });
}
