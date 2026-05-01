import 'package:banka/core/error/exceptions.dart';
import 'package:banka/core/error/failures.dart';
import 'package:banka/features/barcode/data/datasources/barcode_remote_data_source.dart';
import 'package:banka/features/barcode/data/repositories/barcode_repository_impl.dart';
import 'package:banka/features/barcode/domain/entities/barcode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRemote extends Mock implements BarcodeRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late BarcodeRepositoryImpl repo;

  const code = '5449000000996';

  setUp(() {
    remote = _MockRemote();
    repo = BarcodeRepositoryImpl(remote);
  });

  group('lookupBarcode', () {
    test('returns Right(barcode) when found', () async {
      const barcode = Barcode(id: code, drinkName: 'Coca-Cola');
      when(() => remote.lookupBarcode(any())).thenAnswer((_) async => barcode);

      final result = await repo.lookupBarcode(code);

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (b) => b), barcode);
    });

    test('returns Right(null) when document does not exist', () async {
      when(() => remote.lookupBarcode(any())).thenAnswer((_) async => null);

      final result = await repo.lookupBarcode(code);

      expect(result.isRight(), isTrue);
      expect(result.fold((_) => null, (b) => b), isNull);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.lookupBarcode(any()),
      ).thenThrow(const ServerException(message: 'denied'));

      final result = await repo.lookupBarcode(code);

      expect(result.isLeft(), isTrue);
      expect(result.fold((f) => f, (_) => null), isA<ServerFailure>());
    });

    test('maps unknown exception to UnknownFailure', () async {
      when(() => remote.lookupBarcode(any())).thenThrow(StateError('boom'));

      final result = await repo.lookupBarcode(code);

      expect(result.fold((f) => f, (_) => null), isA<UnknownFailure>());
    });
  });

  group('saveBarcode', () {
    test('returns Right(barcode) on success', () async {
      const barcode = Barcode(id: code, drinkName: 'Coca-Cola');
      when(
        () => remote.saveBarcode(
          code: any(named: 'code'),
          drinkName: any(named: 'drinkName'),
          contributedBy: any(named: 'contributedBy'),
          brandId: any(named: 'brandId'),
          brandName: any(named: 'brandName'),
          suggestedPhotoUrl: any(named: 'suggestedPhotoUrl'),
        ),
      ).thenAnswer((_) async => barcode);

      final result = await repo.saveBarcode(
        code: code,
        drinkName: 'Coca-Cola',
        contributedBy: 'uid-1',
      );

      expect(result.fold((_) => null, (b) => b), barcode);
    });

    test('maps ServerException to ServerFailure', () async {
      when(
        () => remote.saveBarcode(
          code: any(named: 'code'),
          drinkName: any(named: 'drinkName'),
          contributedBy: any(named: 'contributedBy'),
          brandId: any(named: 'brandId'),
          brandName: any(named: 'brandName'),
          suggestedPhotoUrl: any(named: 'suggestedPhotoUrl'),
        ),
      ).thenThrow(const ServerException(message: 'denied'));

      final result = await repo.saveBarcode(
        code: code,
        drinkName: 'Coca-Cola',
        contributedBy: 'uid-1',
      );

      expect(result.fold((f) => f, (_) => null), isA<ServerFailure>());
    });
  });
}
