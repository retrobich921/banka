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
        'c_limit,w_400,q_auto,f_auto/v123/banka/posts/p1/0_a.jpg',
      );
    });

    test('уважает кастомную ширину', () {
      const url = 'https://res.cloudinary.com/demo/image/upload/v1/x.jpg';
      expect(cloudinaryThumb(url, width: 200), contains('w_200'));
    });

    test('не трогает URL с уже существующей трансформацией', () {
      const url =
          'https://res.cloudinary.com/demo/image/upload/c_fill,w_100/v1/x.jpg';
      expect(cloudinaryThumb(url), url);
    });

    test('не трогает не-Cloudinary URL', () {
      const url = 'https://example.com/photo.jpg';
      expect(cloudinaryThumb(url), url);
    });
  });
}
