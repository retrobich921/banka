import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/post.dart';
import '../services/image_compressor.dart';

/// Контракт remote-источника фотографий поста (Firebase Storage).
abstract interface class PostImageDataSource {
  Future<PostPhoto> uploadPostImage({
    required String postId,
    required int index,
    required File file,
  });
}

@LazySingleton(as: PostImageDataSource)
final class FirebaseStoragePostImageDataSource implements PostImageDataSource {
  FirebaseStoragePostImageDataSource(this._storage, this._compressor);

  final FirebaseStorage _storage;
  final ImageCompressor _compressor;

  static const String _postsPrefix = 'posts';

  @override
  Future<PostPhoto> uploadPostImage({
    required String postId,
    required int index,
    required File file,
  }) async {
    try {
      final compressed = await _compressor.compress(file);
      final ref = _storage
          .ref()
          .child(_postsPrefix)
          .child(postId)
          .child('${index}_${p.basename(compressed.file.path)}');
      final task = await ref.putFile(
        compressed.file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await task.ref.getDownloadURL();
      return PostPhoto(
        url: url,
        // До срабатывания Cloud Function `onPostImageUploaded` (см.
        // functions/index.js) thumbUrl == url; функция позже подменит.
        thumbUrl: url,
        width: compressed.width,
        height: compressed.height,
      );
    } on FirebaseException catch (e) {
      throw ServerException(message: e.message ?? e.code, cause: e);
    } on FormatException catch (e) {
      throw ServerException(message: e.message, cause: e);
    }
  }
}
