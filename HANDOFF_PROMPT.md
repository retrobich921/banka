# Handoff prompt — для LLM, продолжающей проект **Banka**

Этот файл — **готовый промпт для следующей нейронки** (Claude / GPT / Devin / любой агент со shell-доступом и git-инструментами), которая возьмётся продолжать разработку. Скопируй блок ниже целиком и отдай агенту как первое сообщение.

> Если ты человек и читаешь это, чтобы понять, что в проекте — начни с [README.md](./README.md) и [PROJECT_PLAN.md](./PROJECT_PLAN.md), они написаны для людей. Этот файл — машинный.

---

## ✂️ Скопируй всё, что ниже, и отдай агенту

````
Ты продолжаешь разработку Flutter-приложения **Banka** — социальный каталог для коллекционеров энергетических напитков. Репозиторий: https://github.com/retrobich921/banka.git.

## Контекст

Я уже довёл проект до конца **Sprint 14** (всего 18 спринтов в roadmap). Тебе нужно подхватить и продолжить со **Sprint 15** строго по одному спринту за раз.

### Главные документы (читай их в первую очередь)

1. **`PROJECT_PLAN.md`** — план + архитектура Firestore + roadmap по 18 спринтам с чек-боксами. Это источник правды. Каждый завершённый спринт отмечен `[x]`. Незавершённые — `[ ]`.
2. **`README.md`** — как поднять проект с нуля (Flutter SDK, Firebase config, build_runner, запуск на устройстве, quality gates).
3. **`CONTRIBUTING.md`** — Git workflow (Conventional Commits, branch naming, PR template, branch protection).
4. **`firestore.rules`** — комментированные Security Rules per-collection.
5. **`firestore.indexes.json`** — composite-индексы Firestore.
6. **`functions/index.js`** — Cloud Functions (счётчики, thumbnails).
7. **Сам код в `lib/features/<feature>/`** — паттерны, которые надо повторять.

### Что уже сделано (Sprint 0–14)

| Sprint | Что |
|---|---|
| 0 | Foundation: PROJECT_PLAN, .gitignore, analysis_options, GitHub Actions CI, PR template |
| 1 | Project init: `flutter create`, Clean Architecture скелет, Firebase init, темная тема, go_router |
| 2 | Auth: Google Sign-In + AuthBloc + экраны Splash/SignIn |
| 3 | User profile data + domain (UserProfile, UserStats, UserRepository, 5 usecases) |
| 4 | User profile presentation (ProfileBloc + экран профиля + edit) |
| 5 | Groups data + domain (GroupModel, GroupRepository, members) |
| 6 | Groups presentation (список, создание, экран группы, join/leave) |
| 7 | Posts data + domain + image pipeline + Cloud Function `onPostImageUploaded` |
| 8 | Posts создание (CreatePostBloc + форма) |
| 9 | Posts лента + детальный экран с Hero-анимацией |
| 10 | Likes (транзакция, оптимистичный UI, экран «Кто лайкнул») |
| 11 | Comments (real-time stream, BLoC, экран) |
| 12 | Search (`searchKeywords`, debounce, фильтры по rarity/brand/group) |
| 13 | Brands (коллекция `brands`, экран бренда, BrandPickerSheet, EnsureBrand) |
| 14 | Barcode Scanner (`mobile_scanner`, lookup в `barcodes/{ean}`, autofill drinkName/brand, contribute-back) |

### Что осталось (Sprint 15–18)

- **Sprint 15** — Profile stats & Achievements: Cloud Function пересчёта `users.{uid}.stats` (cansCount, likesReceived, avgRarity, topBrandId), бейджи (entity + правила, экран на профиле).
- **Sprint 16** — Wishlist + Following: подколлекции `users/{uid}/wishlist/{postId}` и `users/{uid}/following/{otherUserId}`, вкладка «Подписки» в ленте.
- **Sprint 17** — Push notifications: FCM-токены в `users.fcmTokens`, Cloud Functions триггеры на новый коммент / лайк / подписчика.
- **Sprint 18** — Polish & Release: empty/error/skeleton states, `firebase_analytics`, Crashlytics, иконки, splash, Firebase App Distribution / Play Internal CD.

Полные требования по каждому спринту — в `PROJECT_PLAN.md § Блок 3`.

## Правила работы (обязательные)

### 1. Один спринт = одна ветка = один PR

- Имя ветки: `feat/sprint-XX-<short-desc>` (например `feat/sprint-15-stats`).
- Никаких прямых пушей в `main` (есть branch protection). Только через PR.
- В PR-описании **обязательно** следуй шаблону `.github/pull_request_template.md`. Заголовок PR: Conventional Commits — `feat(sprint-XX): описание`.
- После создания PR — ждёшь зелёный CI (GitHub Actions: analyze + format + test). Если красный — фиксишь и пушишь снова.
- Юзер мержит PR сам (squash merge). После мержа удаляешь локальную ветку и берёшь следующий спринт.

### 2. Quality gates перед каждым PR

Запусти локально и убедись, что всё зелёное:

```bash
flutter pub get
dart run build_runner build
flutter analyze                            # 0 issues
dart format --set-exit-if-changed .        # 0 changed
flutter test                               # все тесты passing
```

CI прогоняет ровно те же три проверки. Если что-то падает локально — не пушь, исправь.

### 3. Архитектурные паттерны (НЕ нарушай)

- **Clean Architecture per feature**: `lib/features/<feature>/{data,domain,presentation}/`.
- **Domain-слой**: `entities/` (freezed-классы), `repositories/` (абстрактные интерфейсы), `usecases/` (по одному классу на use case, `@lazySingleton`, `call(params)` метод).
- **Data-слой**: `models/` (DTO с `fromMap`/`toMap` или `fromSnapshot`), `datasources/` (абстракция + Firestore-реализация, бросает `ServerException` / `NotFoundException`), `repositories/` (`@LazySingleton(as: ...Repository)`, мапит exception → Failure через `Either`).
- **Presentation-слой**: `bloc/` (sealed events + Equatable state + bloc, `@injectable`), `pages/`, `widgets/`. UI читает state через `BlocBuilder` / `BlocSelector`, диспатчит events через `context.read<Bloc>().add(...)`.
- **`Either<Failure, T>` от dartz** на границе data → domain. UI работает с `state.errorMessage` и `state.status`.
- **DI**: всё, что аннотировано `@injectable` / `@lazySingleton` / `@LazySingleton(as: ...)`, попадает в `injector.config.dart` после `dart run build_runner build`. Не правь `injector.config.dart` руками.
- **Денормализация ради чтения**: дублируй `authorName`, `authorPhotoUrl`, `groupName`, `brandName` в каждый пост; счётчики (`likesCount`, `commentsCount`, `postsCount`) обновляются Cloud Functions / транзакциями, а не клиентом.
- **Темная тема обязательна**: `AppColors.background = #000000`, акцент — `AppColors.primary` (янтарный). Никаких белых фонов.

### 4. Firestore Security Rules

Каждая новая коллекция **обязана** получить блок в `firestore.rules` с явными `allow read/create/update/delete`. Базовый `match /{document=**} { allow read, write: if false; }` в конце файла закрывает всё остальное.

Стандартные паттерны:
- `read: if isSignedIn();` — почти везде.
- `create: if isSignedIn() && request.resource.data.<ownerField> == request.auth.uid;` — для пользовательских данных.
- `update: if ... && request.resource.data.diff(resource.data).affectedKeys().hasOnly([...]);` — чтобы клиент не менял счётчики.

После добавления правил — задеплой:
```bash
firebase deploy --only firestore:rules
```

### 5. Firestore composite-индексы

Любой `where().orderBy()` или `where().where()` запрос требует composite-индекса. Добавь в `firestore.indexes.json` и задеплой:
```bash
firebase deploy --only firestore:indexes
```

Если забудешь — Firestore выбросит `requires an index` runtime-ошибку с готовой ссылкой на UI Console.

### 6. Cloud Functions

Лежат в `functions/index.js`, Node 20, регион `europe-west3`. Триггеры — через `firebase-functions/v2` (Firestore / Storage / scheduled). Деплой:
```bash
cd functions && npm install && firebase deploy --only functions
```

### 7. Тесты

Юнит-тесты для каждой новой фичи — обязательны. Минимум:
- BLoC: 3–5 тестов (happy path, error path, edge cases).
- RepositoryImpl: 2–3 теста (Right-успех, Left на ServerException, Left на UnknownException).
- Datasource: 1–2 теста (вызов нужного метода Firestore).
- DTO нормализаторы / маппинги: 2–3 теста.

Текущий бейзлайн на момент Sprint 14: **176 тестов**. Каждый спринт добавляй 8–15 новых.

Используй `bloc_test`, `mocktail`, `flutter_test`. См. примеры в `test/features/post/presentation/bloc/create_post_bloc_test.dart`.

### 8. Git правила (НЕ нарушай)

- **НЕ** делай `git commit --amend` — это запрещено по rules в моих instructions.
- **НЕ** делай `git push --force` в `main`. В свою feature-ветку только `--force-with-lease`.
- **НЕ** коммить секреты (`.env`, service-account JSON). `firebase_options.dart` и `google-services.json` — публичные конфиги, их можно коммитить.
- **НЕ** запускай `git add .` — добавляй файлы явно или используй паттерны.
- Если pre-commit hook что-то поправил — закоммить вторым коммитом без `--amend`.

### 9. Обновляй PROJECT_PLAN.md

После каждого спринта — отметь подпункты `[x]` в `PROJECT_PLAN.md § Блок 3 → Sprint XX`. Это часть PR. Юзер ориентируется по этому документу.

### 10. Build на устройстве

Юзер билдит на своём Android-телефоне (debug-mode + adb уже настроены). Ты сам с VM не можешь подключиться к его устройству — реальное e2e-тестирование делает юзер. Тебе достаточно:
- зелёного `flutter analyze` + `flutter test`,
- проверки, что приложение собирается (`flutter build apk --debug`).

Если юзер просит протестировать (нажмёт «Test the app» в UI) — используй `enter_test_mode`.

## Что делать прямо сейчас

1. Прочитай `PROJECT_PLAN.md` целиком (это 350 строк, важно).
2. Прочитай `README.md` (как запускать проект).
3. Прочитай `CONTRIBUTING.md` (Git правила).
4. Открой `firestore.rules`, `lib/core/di/injector.dart`, `lib/app/app.dart`, `lib/core/router/app_router.dart` — это «карта» проекта.
5. Изучи структуру одной полностью завершённой фичи: `lib/features/post/` (там есть data, domain, presentation — это эталон).
6. Изучи последнюю фичу `lib/features/barcode/` — как сделана интеграция со сканером и contribute-back в Firestore. Это самый свежий код, паттерны тут самые актуальные.
7. Только после этого начинай **Sprint 15**: Profile stats & Achievements.

## План Sprint 15 (предложение, можешь скорректировать)

**Цель:** показать на профиле живую статистику и бейджи.

1. **Cloud Function `onPostCreatedUpdateUserStats` / `onPostDeletedUpdateUserStats`**: при создании/удалении поста пересчитать `users.{authorId}.stats.cansCount`, `avgRarity`, `topBrandId` (через `runTransaction` + `aggregate query`). Регион `europe-west3`.
2. **Cloud Function `onLikeCreatedUpdateUserStats` / `onLikeDeletedUpdateUserStats`**: пересчитать `users.{postAuthorId}.stats.likesReceived`.
3. **Domain — Achievement**: entity (`id`, `key`, `title`, `description`, `iconAsset`, `unlockedAt`), `AchievementRepository`, usecase `WatchUserAchievements`.
4. **Бейдж-движок (data-слой)**: `users/{uid}/achievements/{key}` подколлекция. Cloud Function `onUserStatsUpdated` (трigger Firestore update) проверяет условия:
   - `first_can`: `stats.cansCount >= 1`.
   - `100_cans`: `stats.cansCount >= 100`.
   - `limited_finder`: есть пост с `rarity >= 8` (отдельный запрос).
   - `popular_collector`: `stats.likesReceived >= 100`.
   - При выполнении условия — `set` документа `achievements/{key}` с `unlockedAt: serverTimestamp()`.
5. **Presentation**: на `ProfilePage` секция «Достижения» (горизонтальный скролл с бейджами, заглушенные пока не разблокированы), секция «Статистика» (cansCount, avgRarity, topBrand, likesReceived).
6. **Firestore Security Rules** для `users/{uid}/achievements/{key}`: read для signed-in, write только Cloud Functions (`if false` на клиенте).
7. **Тесты**: AchievementRepositoryImpl (2–3), WatchUserAchievements usecase (1), ProfileBloc с achievements stream (2). Целевой бейзлайн: ~185 тестов.
8. **Миграция (опционально)**: одноразовая Cloud Function для пересчёта stats у существующих юзеров — но только если юзер попросит.

После согласования с юзером — приступай.

## Финальное

- **Бейзлайн качества:** 0 analyze issues, 0 format diffs, 176+ тестов passing.
- **Контактная точка с юзером:** короткие, по делу. Никаких эмодзи / галочек / лишней похвалы. Юзер любит конкретные ссылки на PR/файлы и краткие отчёты.
- **Когда сомневаешься в скоупе спринта** — спроси юзера прежде чем кодить. Лучше задать вопрос, чем переделывать.
- **Build_runner всегда после изменения freezed/injectable**: `dart run build_runner build`. Без этого `injector.config.dart` устареет и DI сломается на старте.

Удачи. Юзер — Альберт (`@retrobich921`), пишет на русском.
````

---

## Дополнительные ресурсы (для агента)

- Текущий Firebase-проект: `banka-collectors-app` (europe-west3). Console: https://console.firebase.google.com/project/banka-collectors-app
- Owner repo: `@retrobich921` (Альберт, m2407511@edu.misis.ru).
- Все 14 PR'ов мержены через squash merge в `main`. PR'ы 1–15.
- Бейзлайн на момент handoff (2026-04-30): 176 unit-тестов passed, 0 analyze issues, 0 format diffs, CI зелёный.
- Cloud Functions задеплоены в production.
- `lib/firebase_options.dart`, `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist` уже в репо.

## Если что-то идёт не так

- **Не получается собрать APK** → проверь Java JDK 17, `flutter doctor`, `flutter clean && flutter pub get`.
- **Google Sign-In падает с DEVELOPER_ERROR** → SHA-1 дебаг-keystore не зарегистрирован в Firebase Console для текущей машины. Юзер должен сделать сам.
- **Firestore запрос требует индекс** → добавь его в `firestore.indexes.json` и задеплой.
- **Cloud Function не триггерится** → проверь регион (`europe-west3`), проверь логи `firebase functions:log --only <funcName>`.
- **Юзер пишет «давай дальше»** → продолжай со следующего незавершённого спринта в `PROJECT_PLAN.md`.
