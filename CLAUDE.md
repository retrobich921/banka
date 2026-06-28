# CLAUDE.md — правила проекта `banka`

**Продукт.** «банка» — соцсеть + каталог для коллекционеров **напитков**: пользователь
коллекционирует свои находки («банки») и **оценивает любые напитки** (не только
энергетики — газировки, соки, лимонады, что угодно). UI и доменные термины держим
нейтральными к типу напитка.

Подробный стек/структура/домен — в `.kiro/steering/` (`tech.md`, `structure.md`,
`product.md`). При незнании детали **читай их и сам код, а не выдумывай**.

## Принцип №1 — думать про UX, а не только про код
Перед любой правкой, затрагивающей экраны или поведение, **думай о пользователе**:
- Как сюда пришёл пользователь и куда идёт дальше — выстраивай связный пайплайн
  (навигация, переходы, понятные пустые/загрузочные/ошибочные состояния).
- Каждый экран должен быть логичен и единообразен с остальными (тема, отступы,
  компоненты переиспользуем, не плодим разнобой).
- Меньше «мёртвых концов»: после действия пользователь должен понимать результат
  (snackbar/переход/обновление списка), без зависаний и лишних тапов.
- Сначала корректность пользовательского сценария, потом — косметика.

## Стек (кратко)
- **Flutter / Dart** (стабильный канал), таргет — Android (телефон RMX5062, id `3B1F65E9CEQU0N7R`).
- **Clean Architecture** по фичам: `data / domain / presentation` (см. `structure.md`).
- **BLoC** (`flutter_bloc`), **DI** `get_it` + `injectable`, роутинг `go_router`,
  `dartz` (`Either<Failure, T>` на границе data→domain), модели `freezed` + `json_serializable`.
- **Backend Firebase**: Auth + Google Sign-In, Cloud Firestore, Messaging, Functions (`europe-west3`).
  **Firebase Storage НЕ используется** (Spark-план) — изображения грузятся в **Cloudinary**
  через `CloudinaryPostImageDataSource`.

## ⚠️ Кодогенерация — критично
`*.g.dart`, `*.freezed.dart`, `*.config.dart`, `firebase_options.dart` — **в `.gitignore`**
и генерируются локально. После клона / смены ветки / правки аннотаций
(`@injectable`, `@freezed`, `@JsonSerializable`) ОБЯЗАТЕЛЬНО:
    dart run build_runner build --delete-conflicting-outputs
- **Серый экран при запуске** + `Bad state: GetIt: ... AuthBloc is not registered`
  (падение в `app.dart` initState) = устаревший/неполный `injector.config.dart`.
  Лечение: регенерация выше, при упорстве — `flutter clean` и полная пересборка.
- Новая `@injectable`-зависимость без регистрации (напр. незарегистрированный `http.Client`)
  ломает генерацию **всего** конфига → внешние зависимости регистрируй провайдером
  в `FirebaseModule` (`lib/core/di/firebase_module.dart`).

## Проверки (quality gates)
- `flutter analyze` — целимся в 0 issues. **Но он ловит НЕ все ошибки компиляции**
  (напр. пропущенный required named-параметр). Реальная проверка компиляции —
  `flutter test` и `flutter build apk`.
- `dart format --set-exit-if-changed .`
- `flutter test` — должно быть зелёным. Интеграционные тесты Security Rules помечены
  `@Tags(['emulator'])` и по умолчанию пропускаются (`dart_test.yaml`). Запуск с эмулятором:
  `firebase emulators:start --only firestore,auth` → `flutter test --run-skipped --tags emulator`.

## Отладка на телефоне и ЛОГИ (экономия токенов)
**Не дампить сырой `adb logcat`** — на устройстве тонна системного шума, это жжёт токены.
Использовать готовый фильтр-скрипт, который перезапускает приложение и печатает только
строки Dart и фатальные ошибки:
    pwsh scripts/devlog.ps1                 # перезапуск + последние строки flutter
    pwsh scripts/devlog.ps1 -Seconds 12 -Tail 60
    pwsh scripts/devlog.ps1 -NoRestart      # просто снять текущий лог
- ADB не в PATH, путь: `C:\Android\platform-tools\adb.exe`.
- Если нужен разовый фильтр вручную — грепать по `I flutter :` / `FATAL`, шум
  (`SmartSidebar`, `OplusNotification`, `getForegroundApplication`) отбрасывать.

## Сборка и установка на телефон
- Сборка: `flutter build apk` (debug) / `flutter build apk --release`.
- Установка: `flutter install -d 3B1F65E9CEQU0N7R` (по умолчанию ставит **release**),
  либо `adb install -r build\app\outputs\flutter-apk\app-release.apk`.

## UI / тема
- Тема **только тёмная**: `AppColors` (#000000 фон, #FFB300 акцент), `AppTypography`,
  `AppTheme` (Material 3). Цвета не хардкодить мимо `AppColors`.
- Локаль дат — `ru_RU` (инициализируется в `main.dart`).

## Git — порядок работы
Текущая фаза: **чиним баги, НЕ пушим.** Последовательность:
1. Сначала исправляем функциональные баги и UI до стабильного состояния.
2. Когда всё стабильно и красиво — по **явной команде** пользователя делаем один
   аккуратный коммит/пуш «красивой» версии.
3. Только после этого начинаем писать новые фичи.

Правила: не коммитить/пушить напрямую в `main`; ветки `feat/ · fix/ · chore/ · refactor/ · docs/`;
Conventional Commits; коммит/пуш — **только по явной просьбе**; не коммитить секреты и
сгенерированные файлы.

## Окружение
- Windows 11, терминал **PowerShell 7** (`$null`, `$env:VAR`, `;` как разделитель).
- Проект на Flutter — команды `flutter`/`dart` запускай напрямую (не uv/Python).
