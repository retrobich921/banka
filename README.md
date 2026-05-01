# Banka

> Социальное приложение и каталог для коллекционеров энергетических напитков.
> Flutter + BLoC + Clean Architecture + Firebase. Тёмная минималистичная тема.

Пользователи постят, оценивают и обсуждают банки от энергетиков, объединяются в группы, сканируют штрих-коды для автозаполнения, ищут редкие лимитки.

> 📌 **Если ты LLM, которая взялась продолжить этот проект** — начни с [HANDOFF_PROMPT.md](./HANDOFF_PROMPT.md). Там краткая выжимка контекста, правил и текущего состояния спринтов.

---

## Содержание

- [Возможности](#возможности)
- [Стек и архитектура](#стек-и-архитектура)
- [Структура репозитория](#структура-репозитория)
- [Требования](#требования)
- [Полный setup с нуля](#полный-setup-с-нуля)
- [Запуск приложения на Android-устройстве](#запуск-приложения-на-android-устройстве)
- [Запуск приложения в iOS-симуляторе](#запуск-приложения-в-ios-симуляторе)
- [Quality gates (analyze / format / test)](#quality-gates-analyze--format--test)
- [Cloud Functions](#cloud-functions)
- [Firestore Security Rules и индексы](#firestore-security-rules-и-индексы)
- [Частые проблемы](#частые-проблемы)
- [Документы и ссылки](#документы-и-ссылки)
- [Статус и лицензия](#статус-и-лицензия)

---

## Возможности

- Авторизация через Google (Firebase Auth).
- Профиль-коллекционер со статистикой (`stats` денормализованы в `users/{uid}`).
- Группы / коллекции (`groups/{groupId}` + подколлекция `members`).
- Посты-«банки» с несколькими фото (до 6), названием, датой находки, редкостью 1–9, тегами.
- Лента (Все / По группе / По бренду), детальный экран поста с Hero-анимацией.
- Лайки (транзакционно, `likesCount` через Cloud Function) и комментарии (real-time).
- Полноценный поиск по `searchKeywords` с фильтрами (rarity, brand, group).
- Бренды (`brands/{brandId}`) и витрина бренда (постран. лента, отсортированная по `rarity desc`).
- Сканер штрих-кодов EAN-13 / UPC (`mobile_scanner`) с lookup в коллективной базе `barcodes/{ean}` и автозаполнением формы создания поста.

Полная схема Firestore — в [PROJECT_PLAN.md § Блок 2](./PROJECT_PLAN.md).

---

## Стек и архитектура

| Слой | Что используется |
|---|---|
| UI | Flutter 3.35+ / Dart 3.11+ |
| State management | [`flutter_bloc`](https://pub.dev/packages/flutter_bloc) (sealed-events, `Equatable`-state) |
| Архитектура | Clean Architecture: `core/` + `features/<feature>/{data,domain,presentation}/` |
| DI | [`get_it`](https://pub.dev/packages/get_it) + [`injectable`](https://pub.dev/packages/injectable) (codegen в `injector.config.dart`) |
| Routing | [`go_router`](https://pub.dev/packages/go_router) |
| Модели | [`freezed`](https://pub.dev/packages/freezed) + [`json_serializable`](https://pub.dev/packages/json_serializable) |
| Functional | [`dartz`](https://pub.dev/packages/dartz) — `Either<Failure, T>` на границе data → domain |
| Backend | Firebase: Auth, Firestore, Storage, Functions (Node 20), Messaging |
| Сканер | [`mobile_scanner`](https://pub.dev/packages/mobile_scanner) (EAN-13 / UPC / EAN-8) |
| Изображения | `image_picker`, `image` (компрессия), `cached_network_image` |
| Поиск | `stream_transform` (debounce поискового ввода) |

Главный принцип: денормализация ради чтения, счётчики обновляются Cloud Functions, лайки/подписки — подколлекциями. См. [PROJECT_PLAN.md](./PROJECT_PLAN.md).

---

## Структура репозитория

```
banka/
├── lib/
│   ├── core/                 # theme, di, router, errors, typedefs
│   ├── features/
│   │   ├── auth/             # Sprint 2
│   │   ├── user/             # Sprint 3-4
│   │   ├── group/            # Sprint 5-6
│   │   ├── post/             # Sprint 7-9 (data/domain + create + feed)
│   │   ├── like/             # Sprint 10
│   │   ├── comment/          # Sprint 11
│   │   ├── search/           # Sprint 12
│   │   ├── brand/            # Sprint 13
│   │   └── barcode/          # Sprint 14
│   ├── app/app.dart          # Корневой виджет (BlocProvider'ы + MaterialApp.router)
│   ├── firebase_options.dart # Сгенерирован `flutterfire configure` (не секретно)
│   └── main.dart             # entrypoint: Firebase.initializeApp + DI bootstrap
├── functions/                # Cloud Functions (Node 20)
│   └── index.js              # onPostImageUploaded, onLikeCreated/Deleted, onPostCreated/DeletedUpdateBrandStats, ...
├── android/app/
│   ├── google-services.json  # Сгенерирован `flutterfire configure` (не секретно)
│   └── src/main/AndroidManifest.xml  # CAMERA permission для барскода
├── ios/Runner/
│   ├── GoogleService-Info.plist
│   └── Info.plist            # NSCameraUsageDescription
├── firestore.rules           # Security Rules (per-collection)
├── firestore.indexes.json    # composite-индексы
├── firebase.json             # маршруты deploy
├── test/                     # Юнит-тесты (зеркалят структуру lib/)
├── PROJECT_PLAN.md           # Главный документ — план + архитектура + roadmap
├── CONTRIBUTING.md           # Git workflow + Conventional Commits + правила PR
└── HANDOFF_PROMPT.md         # Промпт для LLM, которая продолжает проект
```

---

## Требования

| Инструмент | Версия | Зачем |
|---|---|---|
| Flutter SDK | 3.35.x (channel stable) | Сборка приложения |
| Dart | 3.11.x (идёт со Flutter) | — |
| Java JDK | 17 | Сборка Android (Gradle 8.x) |
| Android SDK + platform-tools | API 34 + последний build-tools | `adb`, сборка APK |
| Xcode | 15+ (только для iOS) | Сборка под iOS-симулятор/устройство |
| Node.js | 20.x | Cloud Functions + `firebase-tools` |
| Firebase CLI | `firebase-tools` ≥ 13 | `flutterfire configure`, deploy rules/indexes/functions |
| FlutterFire CLI | `dart pub global activate flutterfire_cli` | Генерация `firebase_options.dart` |
| Аккаунт Firebase | proj. `banka-collectors-app` (или свой) | Auth, Firestore, Storage, Functions |
| Android-телефон в режиме отладки | — | Тестовая сборка на устройстве |

> Установка Flutter: https://docs.flutter.dev/get-started/install. После установки запусти `flutter doctor` — все галочки кроме «Connected device» должны быть зелёными.

---

## Полный setup с нуля

### Шаг 1. Клонирование и зависимости

```bash
git clone https://github.com/retrobich921/banka.git
cd banka
flutter pub get
```

### Шаг 2. Кодогенерация (freezed / json_serializable / injectable)

```bash
dart run build_runner build
```

Создаст `*.freezed.dart`, `*.g.dart`, `lib/core/di/injector.config.dart`. Эти файлы **не закоммичены** (в `.gitignore`) — генерируются при каждом запуске.

Если ругается на конфликты предыдущей генерации:

```bash
dart run build_runner clean
dart run build_runner build
```

### Шаг 3. Firebase-проект

Текущий продакшен-проект — `banka-collectors-app` (Europe-West3). Файлы конфигурации (`lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) **уже закоммичены в репо** — это публичные конфиги без секретного материала, их безопасно держать в Git.

Если ты хочешь использовать **свой** Firebase-проект (например, для разработки), сделай:

```bash
# 1. Создай проект в https://console.firebase.google.com
# 2. Включи Google Sign-In в Authentication → Sign-in method.
# 3. Включи Firestore Database (production mode, region europe-west3 или ближе к тебе).
# 4. Включи Storage.
# 5. Сгенерируй конфиги (перезапишет существующие):
dart pub global activate flutterfire_cli
flutterfire configure --project=<your-project-id> \
                      --platforms=android,ios \
                      --android-package-name=com.retrobich921.banka \
                      --yes
```

Для Android Google Sign-In нужно зарегистрировать SHA-1 дебаг-keystore:

```bash
cd android && ./gradlew signingReport 2>/dev/null | grep -A1 "Variant: debug" | grep "SHA1:"
```

Полученный SHA-1 добавь в Firebase Console → Project Settings → Android-app → Add fingerprint.

### Шаг 4. Cloud Functions (опционально)

Cloud Functions нужны для счётчиков (`likesCount`, `commentsCount`, `brands.postsCount`) и thumbnails. На клиенте они не блокирующие — приложение работает и без них, просто счётчики не будут обновляться.

Чтобы задеплоить:

```bash
cd functions
npm install
firebase login
firebase use <your-project-id>
firebase deploy --only functions
```

Подробнее — в [functions/README.md](./functions/README.md).

### Шаг 5. Firestore Rules и индексы

```bash
firebase deploy --only firestore:rules,firestore:indexes
```

Без этого composite-индексы не создадутся, и часть запросов (лента группы, бренда, поиск) будет падать с ошибкой `requires an index`.

---

## Запуск приложения на Android-устройстве

1. Включи на телефоне «Режим разработчика» и «Отладка по USB».
2. Подключи телефон по USB. Проверь:
   ```bash
   adb devices
   flutter devices
   ```
   Телефон должен быть в обоих списках.
3. Запуск:
   ```bash
   flutter run                       # debug-сборка с hot reload
   flutter run --release             # release-сборка (без hot reload, но быстрее)
   flutter build apk --release       # APK для ручной установки (`build/app/outputs/flutter-apk/`)
   flutter install                   # установит последний build APK
   ```
4. Логи:
   ```bash
   flutter logs                       # все логи
   adb logcat -s flutter:*           # только Flutter-логи
   ```

---

## Запуск приложения в iOS-симуляторе

```bash
open -a Simulator
flutter run -d ios
```

Для физического iOS-устройства потребуется учётка Apple Developer и подпись через Xcode.

---

## Quality gates (analyze / format / test)

Перед каждым коммитом и в CI прогоняется:

```bash
flutter analyze                            # 0 issues — обязательно
dart format --set-exit-if-changed .        # 0 changed — обязательно
flutter test                               # все тесты — обязательно
```

Все три проверяет [GitHub Actions](./.github/workflows/ci.yaml) на каждый PR. PR с красным CI не мержится.

Запустить отдельный тест:

```bash
flutter test test/features/post/presentation/bloc/create_post_bloc_test.dart
```

С coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html  # требует lcov
open coverage/html/index.html
```

---

## Cloud Functions

См. [functions/README.md](./functions/README.md).

Кратко — какие функции и когда триггерятся:

| Функция | Триггер | Что делает |
|---|---|---|
| `onPostImageUploaded` | Storage finalize | Генерирует thumbnail 400×400, обновляет `posts.{postId}.photos[].thumbUrl` |
| `onLikeCreated` / `onLikeDeleted` | Firestore create/delete `posts/{postId}/likes/{uid}` | `posts.likesCount += 1` / `-= 1` транзакционно |
| `onCommentCreated` / `onCommentDeleted` | Firestore create/delete `posts/{postId}/comments/{commentId}` | `posts.commentsCount += 1` / `-= 1` |
| `onPostCreatedUpdateBrandStats` / `onPostDeletedUpdateBrandStats` | Firestore create/delete `posts/{postId}` | `brands.{brandId}.postsCount += 1` / `-= 1` |

Регион: `europe-west3`.

---

## Firestore Security Rules и индексы

Файлы: [firestore.rules](./firestore.rules) и [firestore.indexes.json](./firestore.indexes.json).

Базовое правило: `request.auth != null` для всего, плюс per-collection ограничения. Документация по правилам — в комментариях прямо в `firestore.rules`.

Composite-индексы:

- `posts`: (`groupId` ASC, `createdAt` DESC), (`authorId` ASC, `createdAt` DESC), (`brandId` ASC, `rarity` DESC), (`searchKeywords` ARRAY, `createdAt` DESC).
- `groups`: (`isPublic` ASC, `postsCount` DESC).

При добавлении нового запроса в репозитории — обнови `firestore.indexes.json` и задеплой через `firebase deploy --only firestore:indexes`.

---

## Частые проблемы

- **`No connected devices`** при `flutter run` — проверь `adb devices`. На некоторых дистрибутивах Linux нужны udev-rules для Android-устройств.
- **`DEVELOPER_ERROR` при Google Sign-In** — не зарегистрирован SHA-1 в Firebase Console (см. Шаг 3).
- **`The query requires an index`** — composite-индекс не создан. Прокинь `firebase deploy --only firestore:indexes` или открой ссылку из ошибки и создай индекс через UI.
- **Build runner ругается на конфликты** — `dart run build_runner clean && dart run build_runner build`.
- **`flutter analyze` ругается на `*.freezed.dart` / `*.g.dart`** — забыл запустить кодогенерацию.
- **CI красный, локально зелёный** — обычно из-за `dart format`. Запусти `dart format .` без флага и закоммить.
- **`mobile_scanner` падает на iOS** — проверь, что в `ios/Runner/Info.plist` есть `NSCameraUsageDescription`.
- **Cloud Functions падают на деплое** — Node 20 обязателен; проверь `node --version` и переустанови при необходимости через `nvm`.

---

## Документы и ссылки

- [PROJECT_PLAN.md](./PROJECT_PLAN.md) — продуктовый план, архитектура Firestore, Roadmap по 18 спринтам с чек-боксами.
- [CONTRIBUTING.md](./CONTRIBUTING.md) — Git workflow, Conventional Commits, требования к PR, branch protection.
- [HANDOFF_PROMPT.md](./HANDOFF_PROMPT.md) — промпт для другой LLM, которая будет продолжать разработку.
- [functions/README.md](./functions/README.md) — Cloud Functions: что делают и как деплоить.
- Firebase Console (текущий проект): https://console.firebase.google.com/project/banka-collectors-app

---

## Статус и лицензия

Прогресс по спринтам — в [PROJECT_PLAN.md](./PROJECT_PLAN.md). На момент написания этого README завершены Sprint 0–14 (Foundation → Auth → Profile → Groups → Posts → Likes → Comments → Search → Brands → Barcode Scanner). Следующие — Sprint 15 (Stats & Achievements), 16 (Wishlist + Following), 17 (Push notifications), 18 (Polish & Release CD).

Лицензия: см. [LICENSE](./LICENSE).
