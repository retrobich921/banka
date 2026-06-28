import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/app.dart';
import 'core/di/injector.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Инициализация локали для DateFormat('...', 'ru_RU') в карточках/постах.
  // Без этого падает LocaleDataException при первом форматировании дат.
  await initializeDateFormatting('ru_RU');

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  await configureDependencies();

  runApp(const BankaApp());
}
