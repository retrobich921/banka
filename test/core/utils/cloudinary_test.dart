import 'package:banka/core/utils/cloudinary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('cloudinaryThumb', () {
    test('вставляет трансформацию в upload-URL', () {
      const url =
          'https://res.cloudinary.com/demo/image/upload/v123/banka/posts/p1/0_a.jpg';
      expect(
        cloudinaryThumb(url),
        'https://res.cloudinary.com/demo/image/upload/'
        'c_limit,w_400,q_auto:good,f_auto/v123/banka/posts/p1/0_a.jpg',
      );
    });

    test('уважает кастомную ширину', () {
      const url = 'https://res.cloudinary.com/demo/image/upload/v1/x.jpg';
      expect(cloudinaryThumb(url, width: 200), contains('w_200'));
    });

    test('заменяет уже существующую трансформацию', () {
      const url =
          'https://res.cloudinary.com/demo/image/upload/c_limit,w_400,q_auto,f_auto/v1/x.jpg';
      expect(
        cloudinaryThumb(url, width: 1080),
        'https://res.cloudinary.com/demo/image/upload/'
        'c_limit,w_1080,q_auto:good,f_auto/v1/x.jpg',
      );
    });

    test('не трогает не-Cloudinary URL', () {
      const url = 'https://example.com/photo.jpg';
      expect(cloudinaryThumb(url), url);
    });
  });

  group('cloudinaryWidthFor', () {
    test('берёт ближайший сверху бакет', () {
      expect(cloudinaryWidthFor(120, 3), 400);
      expect(cloudinaryWidthFor(360, 2), 800);
      expect(cloudinaryWidthFor(360, 3), 1080);
    });

    test('не выходит за максимальный бакет', () {
      expect(cloudinaryWidthFor(800, 4), kCloudinaryWidthBuckets.last);
    });
  });
}
