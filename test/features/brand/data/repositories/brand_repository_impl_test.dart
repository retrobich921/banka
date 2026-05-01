import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/brand/data/datasources/brand_remote_data_source.dart';
import 'package:banka/features/brand/data/repositories/brand_repository_impl.dart';
import 'package:banka/features/brand/domain/entities/brand.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BrandRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late BrandRepositoryImpl repository;

  final brand = Brand(
    id: 'b-1',
    name: 'Monster',
    slug: 'monster',
    postsCount: 3,
    createdAt: DateTime(2025, 1, 1),
    updatedAt: DateTime(2025, 1, 1),
  );

  setUp(() {
    remote = _MockRemote();
    repository = BrandRepositoryImpl(remote);
  });

  group('watchBrands', () {
    test('wraps list in Right', () async {
      when(() => remote.watchBrands()).thenAnswer((_) => Stream.value([brand]));

      final emitted = await repository.watchBrands().take(1).toList();

      expect(emitted.length, 1);
      emitted.first.fold(
        (_) => fail('expected Right'),
        (brands) => expect(brands, [brand]),
      );
    });

    test('converts stream errors to Left(ServerFailure)', () async {
      when(
        () => remote.watchBrands(),
      ).thenAnswer((_) => Stream.error(StateError('boom')));

      final emitted = await repository.watchBrands().toList();

      expect(emitted.length, 1);
      emitted.first.fold(
        (f) => expect(f, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });

  group('watchBrand', () {
    test('emits Right(brand) on success', () async {
      when(
        () => remote.watchBrand('b-1'),
      ).thenAnswer((_) => Stream.value(brand));

      final emitted = await repository.watchBrand('b-1').take(1).toList();

      expect(emitted, [Right<Failure, Brand?>(brand)]);
    });
  });

  group('ensureBrand', () {
    test('returns Right(brand) on success', () async {
      when(
        () => remote.ensureBrand(
          name: any(named: 'name'),
          country: any(named: 'country'),
          logoUrl: any(named: 'logoUrl'),
        ),
      ).thenAnswer((_) async => brand);

      final result = await repository.ensureBrand(name: 'Monster');

      expect(result, Right<Failure, Brand>(brand));
    });

    test('maps ServerException to Left(ServerFailure)', () async {
      when(
        () => remote.ensureBrand(
          name: any(named: 'name'),
          country: any(named: 'country'),
          logoUrl: any(named: 'logoUrl'),
        ),
      ).thenThrow(const ServerException(message: 'denied'));

      final result = await repository.ensureBrand(name: 'Monster');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<ServerFailure>()),
        (_) => fail('expected Left'),
      );
    });

    test('maps generic exception to Left(UnknownFailure)', () async {
      when(
        () => remote.ensureBrand(
          name: any(named: 'name'),
          country: any(named: 'country'),
          logoUrl: any(named: 'logoUrl'),
        ),
      ).thenThrow(StateError('boom'));

      final result = await repository.ensureBrand(name: 'Monster');

      expect(result.isLeft(), isTrue);
      result.fold(
        (failure) => expect(failure, isA<UnknownFailure>()),
        (_) => fail('expected Left'),
      );
    });
  });
}
