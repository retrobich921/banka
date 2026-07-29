import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'firebase_options.dart';

/// Обработчик push'ей, пришедших пока приложение в фоне/убито.
///
/// Работает в отдельном изоляте, поэтому Firebase нужно инициализировать
/// заново. Сам баннер рисует система по notification-payload — здесь
/// ничего показывать не нужно, хендлер обязателен по контракту плагина.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Инициализация локали для DateFormat('...', 'ru_RU') в карточках/постах.
  // Без этого падает LocaleDataException при первом форматировании дат.
  await initializeDateFormatting('ru_RU');

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  await configureDependencies();

  runApp(const BankaApp());
}
