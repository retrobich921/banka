import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Регистрирует «внешние» сервисы Firebase / Google Sign-In в DI-контейнере.
///
/// Все эти классы — синглтоны самих SDK, поэтому регистрируем их как
/// `@lazySingleton` с готовыми инстансами.
///
/// `FirebaseStorage` намеренно отсутствует: с октября 2025 он доступен
/// только на Blaze-плане. Аплоады изображений идут через Cloudinary
/// (`CloudinaryPostImageDataSource`), сам Firebase Storage SDK из проекта
/// удалён.
@module
abstract class FirebaseModule {
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  @lazySingleton
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  @lazySingleton
  FirebaseMessaging get messaging => FirebaseMessaging.instance;

  @lazySingleton
  GoogleSignIn get googleSignIn => GoogleSignIn.instance;

  /// ImagePicker для захвата фото с камеры и галереи
  @lazySingleton
  ImagePicker get imagePicker => ImagePicker();

  /// Константы для ImageCompressor
  @Named('maxLongSide')
  @lazySingleton
  int get maxLongSide => 1600;

  @Named('jpegQuality')
  @lazySingleton
  int get jpegQuality => 85;

  /// SharedPreferences для локального хранения (например, последней выбранной группы)
  @preResolve
  @lazySingleton
  Future<SharedPreferences> get sharedPreferences =>
      SharedPreferences.getInstance();
}
