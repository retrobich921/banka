import 'dart:io';

import 'package:banka/features/post/data/services/image_compressor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

class _TestImageCompressor extends ImageCompressor {
  _TestImageCompressor(this._dir, {super.maxLongSide});

  final Directory _dir;

  @override
  Future<Directory> resolveTemporaryDirectory() async => _dir;
}

void main() {
  late Directory tmpDir;

  setUp(() async {
    tmpDir = await Directory.systemTemp.createTemp('banka-compressor-');
  });

  tearDown(() async {
    if (tmpDir.existsSync()) {
      await tmpDir.delete(recursive: true);
    }
  });

  Future<File> makePngFile(int width, int height) async {
    final image = img.Image(width: width, height: height);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    final bytes = img.encodePng(image);
    final f = File(p.join(tmpDir.path, 'src_${width}x$height.png'));
    await f.writeAsBytes(bytes);
    return f;
  }

  test('downscales when long side exceeds maxLongSide', () async {
    final file = await makePngFile(2400, 1200);
    final compressor = _TestImageCompressor(tmpDir, maxLongSide: 800);
    final out = await compressor.compress(file);

    expect(out.width, 800);
    expect(out.height, 400);
    expect(out.file.existsSync(), isTrue);
    expect(p.extension(out.file.path), '.jpg');
  });

  test('preserves orientation when portrait', () async {
    final file = await makePngFile(900, 1800);
    final compressor = _TestImageCompressor(tmpDir, maxLongSide: 600);
    final out = await compressor.compress(file);
    expect(out.height, 600);
    expect(out.width, 300);
  });

  test('does not upscale when image is smaller than max', () async {
    final file = await makePngFile(400, 300);
    final compressor = _TestImageCompressor(tmpDir, maxLongSide: 1600);
    final out = await compressor.compress(file);
    expect(out.width, 400);
    expect(out.height, 300);
  });

  test('throws on undecodable input', () async {
    final f = File(p.join(tmpDir.path, 'broken.bin'));
    await f.writeAsBytes(<int>[1, 2, 3, 4]);
    final compressor = _TestImageCompressor(tmpDir);
    expect(() => compressor.compress(f), throwsA(isA<FormatException>()));
  });
}
