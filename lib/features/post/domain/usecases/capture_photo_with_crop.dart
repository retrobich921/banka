import 'dart:io';
import 'dart:math';

import 'package:dartz/dartz.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../../core/utils/typedefs.dart';

/// Use case для захвата фото с камеры с автоматическим кропом 1:1.
///
/// Выполняет следующие операции:
/// 1. Проверяет разрешение на доступ к камере
/// 2. Захватывает фото через камеру с ограничением размера 1600x1600
/// 3. Применяет центральный кроп для получения соотношения сторон 1:1
/// 4. Сжимает изображение в JPEG с качеством 85
/// 5. Валидирует размер файла (<5MB)
/// 6. Сохраняет во временную директорию
///
/// Возвращает:
/// - `Right(File)` при успешном захвате и обработке
/// - `Left(PermissionFailure)` если доступ к камере запрещён
/// - `Left(CancelledFailure)` если пользователь отменил захват
/// - `Left(ValidationFailure)` если изображение невалидно или превышает 5MB
/// - `Left(UnknownFailure)` при других ошибках
@lazySingleton
class CapturePhotoWithCrop implements UseCase<File, NoParams> {
  const CapturePhotoWithCrop(this._picker);

  final ImagePicker _picker;

  /// Максимальный размер изображения по большей стороне (пиксели)
  static const int _maxDimension = 1600;

  /// Качество JPEG сжатия (0-100)
  static const int _jpegQuality = 85;

  /// Максимальный размер файла в байтах (5 МБ)
  static const int _maxFileSizeBytes = 5 * 1024 * 1024;

  @override
  ResultFuture<File> call(NoParams params) async {
    try {
      // 1. Проверка разрешения на доступ к камере
      final status = await Permission.camera.status;
      if (!status.isGranted) {
        final requested = await Permission.camera.request();
        if (!requested.isGranted) {
          return const Left(
            PermissionFailure(
              message: 'Доступ к камере запрещён. '
                  'Разрешите доступ в настройках приложения.',
            ),
          );
        }
      }

      // 2. Захват фото с камеры с ограничением размера
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: _maxDimension.toDouble(),
        maxHeight: _maxDimension.toDouble(),
        imageQuality: 100, // Сжатие применим позже для контроля качества
      );

      // Пользователь отменил захват
      if (xFile == null) {
        return const Left(
          CancelledFailure(message: 'Захват фото отменён пользователем'),
        );
      }

      // 3. Загрузка и декодирование изображения
      final bytes = await xFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        return const Left(
          ValidationFailure(
            message: 'Не удалось декодировать изображение. '
                'Попробуйте сделать снимок ещё раз.',
          ),
        );
      }

      // 4. Применение центрального кропа для получения 1:1
      final size = min(image.width, image.height);
      final offsetX = (image.width - size) ~/ 2;
      final offsetY = (image.height - size) ~/ 2;

      final cropped = img.copyCrop(
        image,
        x: offsetX,
        y: offsetY,
        width: size,
        height: size,
      );

      // 5. Сжатие в JPEG с качеством 85
      final compressed = img.encodeJpg(cropped, quality: _jpegQuality);

      // 6. Валидация размера файла (<5MB)
      if (compressed.length > _maxFileSizeBytes) {
        return const Left(
          ValidationFailure(
            message: 'Размер изображения превышает 5 МБ. '
                'Попробуйте сделать снимок в условиях с меньшей детализацией.',
          ),
        );
      }

      // 7. Сохранение во временную директорию
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${tempDir.path}/captured_$timestamp.jpg');
      await file.writeAsBytes(compressed);

      return Right(file);
    } catch (e) {
      // Обработка всех остальных ошибок
      return Left(
        UnknownFailure(
          message: 'Произошла ошибка при захвате фото: ${e.toString()}',
          cause: e,
        ),
      );
    }
  }
}
