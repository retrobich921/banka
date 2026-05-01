import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Сервис компрессии фото перед загрузкой в Firebase Storage.
///
/// Цель — снизить нагрузку на Storage и трафик ленты. Параметры:
///  - длинная сторона ≤ 1600 px,
///  - JPEG, качество 85,
///  - сохраняется во временный каталог (по умолчанию
///    `getTemporaryDirectory()`), оригинал не трогаем.
///
/// Для unit-тестов наследуйся и переопредели `resolveTemporaryDirectory()`.
@lazySingleton
class ImageCompressor {
  const ImageCompressor({this.maxLongSide = 1600, this.jpegQuality = 85});

  final int maxLongSide;
  final int jpegQuality;

  /// Точка переопределения для тестов: позволяет подменить временный
  /// каталог, не трогая `path_provider` (он требует FlutterBinding).
  Future<Directory> resolveTemporaryDirectory() => getTemporaryDirectory();

  /// Возвращает [CompressedImage] с путём к сжатому файлу и его размерами.
  /// Если изображение уже меньше `maxLongSide` — конвертирует в JPEG
  /// без апскейла.
  Future<CompressedImage> compress(File source) async {
    final bytes = await source.readAsBytes();
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } catch (e) {
      throw FormatException('Не удалось декодировать изображение: $e');
    }
    if (decoded == null) {
      throw const FormatException('Не удалось декодировать изображение');
    }

    final long = decoded.width >= decoded.height
        ? decoded.width
        : decoded.height;

    final img.Image resized;
    if (long > maxLongSide) {
      resized = decoded.width >= decoded.height
          ? img.copyResize(decoded, width: maxLongSide)
          : img.copyResize(decoded, height: maxLongSide);
    } else {
      resized = decoded;
    }

    final encoded = img.encodeJpg(resized, quality: jpegQuality);

    final dir = await resolveTemporaryDirectory();
    final outName =
        '${DateTime.now().millisecondsSinceEpoch}_'
        '${p.basenameWithoutExtension(source.path)}.jpg';
    final outFile = File(p.join(dir.path, outName));
    await outFile.writeAsBytes(encoded, flush: true);

    return CompressedImage(
      file: outFile,
      width: resized.width,
      height: resized.height,
    );
  }
}

class CompressedImage {
  const CompressedImage({
    required this.file,
    required this.width,
    required this.height,
  });

  final File file;
  final int width;
  final int height;
}
