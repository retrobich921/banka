import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../../../core/utils/cloudinary.dart';
import '../../domain/entities/post.dart';
import '../services/image_compressor.dart';

/// Контракт remote-источника фотографий поста.
///
/// Изначально реализация была на Firebase Storage, но с октября 2025 на
/// Spark (бесплатном) плане Storage недоступен. Поэтому фото заливаются в
/// Cloudinary через unsigned upload preset, а в Firestore сохраняется
/// итоговый `secure_url`.
abstract interface class PostImageDataSource {
  Future<PostPhoto> uploadPostImage({
    required String postId,
    required int index,
    required File file,
  });
}

/// Реализация поверх Cloudinary REST API (unsigned upload).
///
/// Эндпойнт: `POST https://api.cloudinary.com/v1_1/{cloud}/image/upload`
/// multipart-форма:
///  - `file`: байты сжатого JPEG;
///  - `upload_preset`: имя unsigned-пресета;
///  - `folder`: `banka/posts/{postId}` — для удобной навигации в Cloudinary;
///  - `public_id`: `{index}_{filename}` — стабильный ID без расширения.
///
/// Ответ JSON содержит `secure_url`, `width`, `height` — заполняем
/// `PostPhoto`. До спринта с трансформациями `thumbUrl == url`.
@LazySingleton(as: PostImageDataSource)
final class CloudinaryPostImageDataSource implements PostImageDataSource {
  CloudinaryPostImageDataSource(this._compressor);

  final ImageCompressor _compressor;
  final http.Client _httpClient = http.Client();

  /// Cloudinary product environment cloud name. Публично безопасно.
  static const String _cloudName = 'dwdum85wx';

  /// Имя unsigned upload preset (Settings → Upload → Upload presets).
  /// Безопасно лежать в клиенте, т.к. подразумевает только аплоад.
  static const String _uploadPreset = 'banka921';

  /// Префикс папки в Cloudinary, чтобы удобно было чистить.
  static const String _folderPrefix = 'banka/posts';

  Uri get _endpoint =>
      Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');

  @override
  Future<PostPhoto> uploadPostImage({
    required String postId,
    required int index,
    required File file,
  }) async {
    try {
      final compressed = await _compressor.compress(file);

      final request = http.MultipartRequest('POST', _endpoint)
        ..fields['upload_preset'] = _uploadPreset
        ..fields['folder'] = '$_folderPrefix/$postId'
        ..fields['public_id'] =
            '${index}_${p.basenameWithoutExtension(compressed.file.path)}'
        ..files.add(
          await http.MultipartFile.fromPath('file', compressed.file.path),
        );

      final streamed = await _httpClient.send(request);
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServerException(
          message:
              'Cloudinary upload failed (${response.statusCode}): ${response.body}',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String?;
      if (secureUrl == null || secureUrl.isEmpty) {
        throw ServerException(
          message: 'Cloudinary не вернул secure_url: ${response.body}',
        );
      }

      final width = (json['width'] as num?)?.toInt() ?? compressed.width;
      final height = (json['height'] as num?)?.toInt() ?? compressed.height;

      return PostPhoto(
        url: secureUrl,
        thumbUrl: cloudinaryThumb(secureUrl),
        width: width,
        height: height,
      );
    } on ServerException {
      rethrow;
    } on FormatException catch (e) {
      throw ServerException(message: e.message, cause: e);
    } on http.ClientException catch (e) {
      throw ServerException(message: 'Сеть недоступна: ${e.message}', cause: e);
    } catch (e) {
      throw ServerException(message: e.toString(), cause: e);
    }
  }
}
