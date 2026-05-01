import 'package:banka/features/brand/data/models/brand_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BrandDto.slugify', () {
    test('lowercases, replaces spaces with single dash', () {
      expect(BrandDto.slugify('Monster Energy'), 'monster-energy');
    });

    test('strips trademark / non-alphanumeric symbols', () {
      expect(BrandDto.slugify('Monster Energy®'), 'monster-energy');
      expect(BrandDto.slugify('Red Bull™'), 'red-bull');
    });

    test('collapses multiple spaces and dashes', () {
      expect(BrandDto.slugify('  Red    Bull  '), 'red-bull');
      expect(BrandDto.slugify('--foo---bar--'), 'foo-bar');
    });

    test('preserves cyrillic letters', () {
      expect(BrandDto.slugify('Адреналин'), 'адреналин');
    });

    test('returns empty string for whitespace-only input', () {
      expect(BrandDto.slugify('   '), '');
      expect(BrandDto.slugify('!!!'), '');
    });

    test('is idempotent — slugify(slugify(x)) == slugify(x)', () {
      const input = 'Monster Energy®';
      final once = BrandDto.slugify(input);
      final twice = BrandDto.slugify(once);
      expect(twice, once);
    });
  });
}
