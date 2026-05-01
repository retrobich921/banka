import 'package:banka/features/barcode/data/models/barcode_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BarcodeDto.normalize', () {
    test('strips spaces and dashes', () {
      expect(BarcodeDto.normalize('5449 0000 0099 6'), '5449000000996');
      expect(BarcodeDto.normalize('5449-0000-0099-6'), '5449000000996');
    });

    test('keeps only digits', () {
      expect(BarcodeDto.normalize('EAN: 4607081320169'), '4607081320169');
    });

    test('returns empty string for non-digit input', () {
      expect(BarcodeDto.normalize(''), '');
      expect(BarcodeDto.normalize('---'), '');
      expect(BarcodeDto.normalize('abc'), '');
    });

    test('idempotent on already-normalized input', () {
      expect(BarcodeDto.normalize('1234567890123'), '1234567890123');
      expect(
        BarcodeDto.normalize(BarcodeDto.normalize('  1234567890 ')),
        '1234567890',
      );
    });
  });
}
