import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/app.dart';
import 'core/di/injector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO(sprint-2): после flutterfire configure инициализировать Firebase здесь:
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  await configureDependencies();

  runApp(const BankaApp());
}
