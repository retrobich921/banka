import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injector.config.dart';

/// Глобальный сервис-локатор. Регистрации генерируются `injectable_generator`
/// и собираются в `injector.config.dart` (`init()`-расширение ниже).
final GetIt sl = GetIt.instance;

@InjectableInit(
  initializerName: 'init',
  preferRelativeImports: true,
  asExtension: true,
)
Future<void> configureDependencies() async {
  // ВАЖНО: обязательно await — сгенерированный `init()` асинхронный из-за
  // `@preResolve` (SharedPreferences). Без await функция вернётся до того, как
  // зарегистрируются зависимости после первого await внутри init (напр.
  // AuthBloc), и `sl<AuthBloc>()` в app.dart упадёт «not registered».
  await sl.init();
}
