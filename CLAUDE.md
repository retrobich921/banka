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
`*.g.dart`, `*.freezed.dart`, `*.config.dart` — **в `.gitignore`**, генерируются локально
(`firebase_options.dart` — закоммичен, нужен CI). После клона / смены ветки / правки аннотаций
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

## Паттерны проекта (кодить быстрее, тратить меньше токенов)
- **Добавляешь поле/фичу — веди по слоям среза ПО ПОРЯДКУ, не переоткрывая весь срез:**
  `entity` → `*_dto.dart` (`fromMap`/`toFirestoreMap`) → `*_repository.dart` (контракт) →
  `*_repository_impl.dart` → `*_remote_data_source.dart` (контракт + impl) →
  `usecase` (+`Params`) → `bloc` (event/state/handler/submit) → UI →
  `firestore.rules` (валидация) → тесты → `build_runner`. Это типовой путь — не
  исследуй архитектуру заново каждый раз.
- **Обратная совместимость с Firestore:** новые поля делать nullable / `@Default`,
  в `fromMap` читать с дефолтом; неизвестный enum-ключ → безопасный дефолт + маппинг
  легаси-ключей (пример: `DrinkType.fromKey`). Старые документы не должны ломаться.
- **Денорм-счётчики (likes/comments/postsCount):** Cloud Functions на Spark НЕ
  выполняются. Считать на клиенте — инкремент в батче при создании, либо агрегатный
  `count()` (см. `watchBrands`/`watchBrand`). Не полагаться на функции.
- **Лента:** первая страница realtime (`Watch*Feed`), догрузка — курсором
  (`FetchFeedPage`, `startAfter`, без перечитывания). Скоупы — `PostsFeedScope`
  (`global/group/brand/author`). Переиспользуй `PostsFeedView`/`PostsFeedBloc`.
- **Переиспользуй, не плоди дубли:** общие виджеты (`RatingScoreBadge`, `_Pill`/чипы,
  карточки), тему, скоупы. Мок-тесты блоков ломаются при смене конструктора — правь
  `registerFallbackValue` и сигнатуры в тестах сразу.
- **Токены:** НЕ читать сгенерированные файлы (`*.g.dart`/`*.freezed.dart`/`*.config.dart`/
  `firebase_options.dart`) — выводи из аннотаций-источников. В итерации гонять
  `flutter analyze <папка>` по затронутому, полный набор гейтов — перед коммитом.
  `.kiro/steering` + этот файл — истина, не переоткрывать срез «для контекста».

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
- Не коммитить/пушить напрямую в `main`; ветки `feat/ · fix/ · chore/ · refactor/ · docs/ · ci/`;
  **Conventional Commits**; коммит/пуш — **только по явной просьбе**.
- **Контрибьюторы: НИКОГДА не добавлять `Co-Authored-By` / любых соавторов в коммиты.**
  Коммиты — только от пользователя (это попадает в граф контрибьюторов и release notes).
- **Секреты не коммитить:** `key.properties`, `*.jks`, `.kiro/settings/mcp.json`. Уже в
  `.gitignore`. `firebase_options.dart` и `google-services.json` закоммичены осознанно —
  нужны CI для сборки (клиентские ключи, не секрет).
- **Релизы:** bump `version:` в `pubspec.yaml` → тег `vX.Y.Z` → GitHub Actions
  (`.github/workflows/release.yml`) собирает подписанный **`banka-<tag>.apk`** и публикует
  GitHub Release; приложение само находит обновление (`lib/core/update/app_updater.dart`).
  Подпись — release-keystore через `android/key.properties` (вне git; SHA-1 ключа должен
  быть в Firebase, иначе Google Sign-In падает).

## Окружение
- Windows 11, терминал **PowerShell 7** (`$null`, `$env:VAR`, `;` как разделитель).
- Проект на Flutter — команды `flutter`/`dart` запускай напрямую (не uv/Python).
