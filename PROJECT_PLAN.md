# 📐 Banka — Project Plan

> Социальное приложение и каталог для коллекционеров энергетических напитков.
> Пользователи постят, оценивают и обсуждают банки от энергетиков, объединяются в группы/коллекции.

**Repo:** https://github.com/retrobich921/banka.git
**Stack:** Flutter + BLoC + Clean Architecture + Firebase (Auth / Firestore / Storage / Functions / Messaging) + get_it/injectable + go_router
**Тема:** строгая тёмная (`#000000` фон, серые акценты `#0F0F0F` / `#1A1A1A` / `#2A2A2A`, белый текст, единый акцент-цвет — янтарный `#FFB300`)

---

## 🎯 Концепт

- Посты-«банки» с несколькими фото (карусель), названием, датой находки, оценкой редкости (1–9).
- Группы/коллекции, в которые пользователи постят свои находки.
- Соцмеханики: лайки на банки, комментарии под постами.
- Полноценный поиск по базе банок.
- Авторизация через Google (Firebase Auth).
- Firestore (БД) + Firebase Storage (фото).

---

## 🟦 Блок 1. Продуктовые улучшения (5 фич сверх ТЗ)

1. **Профиль-коллекционер со статистикой и достижениями.** Количество банок, средняя редкость, топ-бренд, карта стран, бейджи («Первая банка», «100 банок», «Нашёл лимитку» при `rarity ≥ 8`).
2. **Бренды и теги как нормализованные сущности.** Отдельная коллекция `brands` (Red Bull, Monster, Adrenaline, Burn, Tornado…) и теги (`limited`, `holiday`, `regional`, `vintage`) для фасетного поиска и витрин бренда.
3. **Сканер штрих-кодов (EAN-13/UPC).** Подтягиваем `drinkName`/`brand` из коллективной коллекции `barcodes`. Отсутствующие штрих-коды сохраняем туда же — следующий пользователь получает автозаполнение.
4. **Автоматический пайплайн фото:** на клиенте — компрессия и ресайз (≤ 1600 px по длинной стороне, JPEG q=85) перед заливкой в Storage; на бэке — Cloud Function `onPostImageUploaded`, делающая thumbnail 400×400 для лент.
5. **Wishlist + лента подписок.** «Хочу найти» (закладки) и лента «Подписки» (посты от тех, на кого подписан) — каталог превращается в живую соцсеть.

*Бонус (если зайдёт):* deep-links на пост через `firebase_dynamic_links`/App Links, репорт-кнопка для модерации, оффлайн-кеш ленты на `hive`/`isar`.

---

## 🟦 Блок 2. Архитектура Firestore

Принципы: денормализация для чтения, счётчики через транзакции/Cloud Functions, лайки/подписки — подколлекциями (дёшево читать «лайкнул ли я» одним `get`), пагинация через `orderBy + startAfterDocument`, поиск — массив `searchKeywords` (lowercase токены) на старте, при росте — Algolia/Typesense.

```
users/{userId}
  displayName, email, photoUrl, bio, createdAt
  stats: { cansCount, likesReceived, groupsCount, avgRarity, topBrandId }
  fcmTokens: [..]

users/{userId}/likedPosts/{postId}        // быстрый ответ "лайкал ли я"
  createdAt

users/{userId}/wishlist/{postId}
  createdAt

users/{userId}/following/{otherUserId}
  createdAt

groups/{groupId}
  name, description, ownerId, coverUrl, isPublic,
  membersCount, postsCount, createdAt, tags[]

groups/{groupId}/members/{userId}
  role: 'owner'|'admin'|'member', joinedAt

posts/{postId}                            // плоская коллекция — главная
  authorId, authorName, authorPhotoUrl,   // денорм для ленты без join
  groupId, groupName,                     // денорм
  drinkName, brandId, brandName,          // денорм
  photos: [ { url, thumbUrl, width, height } ],
  foundDate (Timestamp),                  // дефолт = createdAt, редактируется
  rarity (1..9),
  description,
  tags: [..],
  likesCount, commentsCount,
  searchKeywords: [..],                   // lowercase токены drinkName + brand + tags
  createdAt, updatedAt

posts/{postId}/likes/{userId}             // подколлекция — атомарные лайки
  createdAt

posts/{postId}/comments/{commentId}
  authorId, authorName, authorPhotoUrl,
  text, createdAt, likesCount

brands/{brandId}                          // справочник
  name, slug, logoUrl, country, postsCount

barcodes/{ean}                            // коллективная база штрих-кодов
  drinkName, brandId, suggestedPhotoUrl, contributedBy, createdAt

reports/{reportId}                        // модерация
  targetType, targetId, reporterId, reason, status, createdAt
```

**Composite indexes:**
- `posts`: (`groupId` ASC, `createdAt` DESC), (`authorId` ASC, `createdAt` DESC), (`brandId` ASC, `rarity` DESC), (`searchKeywords` ARRAY, `createdAt` DESC)
- `groups`: (`isPublic` ASC, `postsCount` DESC)

**Логика лайка (одна транзакция):**
1. `posts/{postId}/likes/{uid}` создать.
2. `posts/{postId}.likesCount` += 1.
3. `users/{uid}/likedPosts/{postId}` создать.

Дизлайк — обратные 3 операции в той же транзакции.

**Пагинация:** `query.orderBy('createdAt', desc).limit(20).startAfterDocument(lastDoc)`.

**Security Rules (черновик):** auth обязателен; `posts.authorId == request.auth.uid` для write/update; `likesCount` / `commentsCount` редактируются только Cloud Functions (server-side).

---

## 🟦 Блок 3. Roadmap

> Чек-боксы обновляются по мере выполнения. После каждого спринта PR должен быть смержен в `main`, и только тогда галочки спринта закрываются.

### Sprint 0 — Foundation & DevOps ✅

- [x] Ветки `main` (защищённая) и `chore/sprint-0-foundation`.
- [x] `PROJECT_PLAN.md` с чек-боксами (этот файл).
- [x] `README.md` с описанием проекта и инструкцией запуска.
- [x] `CONTRIBUTING.md` с правилами Git/Conventional Commits.
- [x] `.gitignore` под Flutter + Dart + IDE + Firebase.
- [x] `analysis_options.yaml` с `flutter_lints` (или `very_good_analysis`).
- [x] `.github/workflows/ci.yaml` — `dart format --set-exit-if-changed` + `flutter analyze` + `flutter test` (с guard на наличие `pubspec.yaml`).
- [x] `.github/pull_request_template.md`.
- [x] PR Sprint 0 → ревью → мерж (PR #1).

### Sprint 1 — Project Init

- [x] `flutter create banka` (org `com.retrobich921.banka`).
- [x] Структура Clean Architecture: `lib/core/{di,error,router,theme,utils}` (network/data/domain слои фич появятся, когда понадобятся, чтобы не плодить пустые директории).
- [x] Не-Firebase зависимости: `flutter_bloc`, `bloc`, `get_it`, `injectable`, `go_router`, `equatable`, `dartz`, `freezed_annotation`, `json_annotation`, `intl`.
- [x] Dev: `build_runner`, `freezed`, `injectable_generator`, `json_serializable`, `flutter_lints`, `bloc_test`, `mocktail`.
- [x] `core/theme` — тёмная тема (`#000000`, акцент `#FFB300`, типографика, Material 3 component themes).
- [x] `core/di` — get_it + injectable + сгенерированные регистрации (`AppRouter`).
- [x] `core/router` — go_router скелет (Splash → SignIn → Home).
- [x] `core/error` — `Failure`, `AppException`, `ResultFuture<T>`.
- [x] Smoke-тест: `BankaApp` грузится, splash → sign-in.
- [x] PR Sprint 1 → CI → ревью → мерж.

> Перенесено в Sprint 2 (требует google-services.json, без него Android Gradle падает):
> - `flutterfire configure` (Android + iOS).
> - Firebase-зависимости: `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `google_sign_in`.
> - Image-зависимости (`image`, `image_picker`, `cached_network_image`, `mobile_scanner`) — переедут в свои спринты (7, 14).
> - Сборка debug-APK на телефоне (вместе с Firebase init).

### Sprint 2 — Auth (Google Sign-In)

- [x] `flutterfire configure --project=banka-collectors-app` — сгенерированы `lib/firebase_options.dart` и `android/app/google-services.json`.
- [x] Добавлены deps: `firebase_core`, `firebase_auth`, `google_sign_in` (7.x), `cloud_firestore`, `firebase_storage`, `firebase_messaging`.
- [x] `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` в `main.dart`.
- [ ] Сборка debug-APK на подключённом телефоне (проверка, что Firebase инициализируется без ошибок) — после мержа PR Sprint 2.
- [x] Data: `AuthRemoteDataSource` (FirebaseAuth + GoogleSignIn 7.x), `AuthRepositoryImpl` с маппингом `Failure`.
- [x] Domain: `AuthUser` entity, usecases (`SignInWithGoogle`, `SignOut`, `WatchAuthState`).
- [x] Presentation: `AuthBloc` (events: `AuthStarted`, `AuthGoogleSignInRequested`, `AuthSignOutRequested`), экраны Splash + SignIn (минимализм: лого, одна кнопка «Войти через Google»).
- [x] Auth-aware redirect в `AppRouter` на основе `AuthBloc.state`.
- [x] Защита Firestore/Storage Rules: `request.auth != null` (`firestore.rules`, `storage.rules`, `firebase.json`).
- [x] Тесты: `AuthBloc` (bloc_test + mocktail) + smoke widget tests SignIn/Home.
- [ ] PR Sprint 2 → CI → ревью → мерж.

> **Что должен сделать owner один раз перед запуском на устройстве:**
> 1. Открыть https://console.firebase.google.com/project/banka-collectors-app/authentication/providers и включить **Google** провайдер (Identity Platform требует billing, поэтому по REST API не включается). После этого Firebase сам создаст web-OAuth-клиент.
> 2. Прислать debug SHA-1 от своего keystore (`./gradlew signingReport` из `android/`) — добавлю в Firebase-app через `firebase apps:android:sha:create`. Без SHA-1 Google Sign-In вернёт `DEVELOPER_ERROR` на устройстве.
> 3. После шагов 1–2 — `flutterfire configure --project=banka-collectors-app` (обновит `google-services.json` с oauth_client'ом) и пересборка APK.

### Sprint 3 — User profile (data + domain)

- [x] `UserProfile` + `UserStats` entities (freezed).
- [x] `UserRepository` контракт (getUser, watchUser, watchUserStats, ensureUserDocument, updateProfile).
- [x] Usecases: `GetUser`, `WatchUser`, `WatchUserStats`, `EnsureUserDocument`, `UpdateProfile`.
- [x] Data: `UserProfileDto` (Firestore ↔ entity), `UserRemoteDataSource` + `FirestoreUserRemoteDataSource`, `UserRepositoryImpl` с `Either<Failure, T>`.
- [x] DI: всё подхватывается `injectable` через существующий `FirebaseFirestore` из `FirebaseModule`.
- [x] Тесты: DTO round-trip + repository (25 passed).
- [ ] PR Sprint 3 → CI → ревью → мерж.

### Sprint 4 — User profile (presentation)

- [x] `ProfileBloc`: `ProfileSubscribeRequested` (ensure doc + watch стрим), `ProfileEditSubmitted`, `ProfileResetRequested`.
- [x] Экран профиля: аватар, имя, email, био, сетка статистики (банок / лайков / групп / средняя редкость).
- [x] Экран редактирования: форма displayName + bio, валидация, snackbar при ошибке, авто-выход после сохранения.
- [x] Роуты `/profile`, `/profile/edit` под общим `ShellRoute` с `ProfileBloc`.
- [x] HomePage: иконка-кнопка перехода в профиль.
- [x] Тесты `ProfileBloc` (4 кейса) + обновлён `widget_test.dart`. Всего 29 passed.
- [ ] Табы «Мои банки» / «Группы» — отложены до Sprint 9 (как только появятся посты/группы).
- [ ] PR Sprint 4 → CI → ревью → мерж.

### Sprint 5 — Groups (data + domain)

- [x] Domain: `Group`, `GroupMember`, `GroupRole` (freezed, immutable), `GroupRepository` контракт, 10 usecases (`Create/Get/Watch/Update/Delete`, `Join/Leave`, `WatchMy/WatchPublic/WatchGroupMembers`).
- [x] Data: `GroupDto`, `GroupMemberDto`, `FirestoreGroupRemoteDataSource` (атомарные `WriteBatch` для create/join/leave с денорм-массивом `membersUids`), `GroupRepositoryImpl` (Either-маппинг).
- [x] Security Rules: `users` + `groups/{id}` + `groups/{id}/members/{uid}` (создатель = owner, leave = self, update = owner).
- [x] Composite indexes для `membersUids+updatedAt` и `isPublic+postsCount`.
- [x] Тесты DTO round-trip + repository (мок-источник). Всего 45 passed.
- [ ] PR Sprint 5 → CI → ревью → мерж.

### Sprint 6 — Groups (presentation)

- [x] `GroupsListBloc` — две real-time подписки (мои + публичные) + creation flow.
- [x] `GroupDetailBloc` — подписка на группу + members, команды join / leave / delete.
- [x] Экран `/groups` с табами «Мои» / «Открытые», FAB на создание, переход на новый `/groups/:id` после создания.
- [x] Экран `/groups/new` — форма (название, описание, switch публичности) с валидацией.
- [x] Экран `/groups/:id` — обложка, счётчики, кнопка вступить/выйти, кнопка удаления для владельца, список участников.
- [x] Кнопка «Группы» на главном экране.
- [x] Тесты `GroupsListBloc` (4 кейса) + `GroupDetailBloc` (5 кейсов). Всего 55 passed.
- [ ] PR Sprint 6 → CI → ревью → мерж.

### Sprint 7 — Posts/Cans (data + domain) ⭐ ядро

- [x] `Post`/`PostPhoto` entities (freezed) + `PostRepository` контракт (createPost, watchFeed, watchGroupFeed, watchAuthorFeed, getPost, watchPost, updatePost, deletePost).
- [x] 8 use-cases в `lib/features/post/domain/usecases/` + `UploadPostImage`.
- [x] `PostDto` + `PostPhotoDto` ↔ Firestore (round-trip, `searchKeywords` builder lowercase + dedup ≥ 2 chars).
- [x] `FirestorePostRemoteDataSource` (атомарный create через `WriteBatch`: `posts/` + denorm-инкремент `groups.postsCount` + `users.stats.cansCount`).
- [x] `PostRepositoryImpl` с маппингом исключений → `Failure`.
- [x] `ImageCompressor` (`image` пакет, JPEG q=85, длинная сторона ≤ 1600 px) + `FirebaseStoragePostImageDataSource` + `PostStorageRepositoryImpl`.
- [x] Storage prefix `posts/{postId}/{n}_{filename}`, контракт под Cloud Function.
- [x] `firestore.rules` для `posts/` (owner-only mutate, `likesCount`/`commentsCount`/`rarity` валидируются на create) + `storage.rules` (image-only, < 8 MB).
- [x] Composite indexes для `groupId+createdAt`, `authorId+createdAt`, `brandId+rarity`, `searchKeywords+createdAt`.
- [x] `functions/index.js` с `onPostImageUploaded` (sharp 400×400 thumbnail) + `firebase.json` подхватывает functions.
- [x] Тесты: `PostDto` (5), `PostRepositoryImpl` (10), `ImageCompressor` (4). Всего 77 passed.
- [x] PR Sprint 7 → CI → ревью → мерж.

### Sprint 8 — Posts: создание поста (presentation)

- [x] `CreatePostBloc` (events / state / handlers, последовательная загрузка фото, прогресс, ошибки, валидация).
- [x] `CreatePostPage`: multi-picker фото (до 6), drinkName, brand, foundDate (default = today), rarity-slider 1–9, tags chips, description, group-selector (опционально).
- [x] Маршрут `/posts/new` + кнопки «Запостить банку» на `HomePage` и `GroupDetailPage` (с прокидыванием `groupId/groupName` через `extra`).
- [x] Тесты `CreatePostBloc` (12 кейсов: init, photo cap, rarity clamp, валидации, upload-flow, ошибки, ack/reset). Всего 89 passed.
- [ ] PR Sprint 8 → CI → ревью → мерж.

### Sprint 9 — Posts: лента + детальный экран

- [x] `PostsFeedBloc` — стрим ленты по скоупу `global` или `group(id)` с переоткрытием подписки при смене скоупа и обработкой `Failure`.
- [x] `PostDetailBloc` — стрим конкретного поста, состояния `loading / ready / notFound / error`.
- [x] Глобальная лента на `HomePage` (вынесен `HomeView` для тестов; AppBar с переходами в группы / профиль / sign-out, FAB «Запостить банку»).
- [x] Лента группы на `GroupDetailPage` (`PostsFeedBloc` с `PostsFeedScope.group(id)` параллельно с `GroupDetailBloc`).
- [x] Карточка `PostCard` — шапка автора, swipeable-карусель фото, индикаторы, бейдж редкости, чипы бренда/группы, теги, `Hero(tag: 'post-photo-{id}')` на первом кадре.
- [x] `PostDetailPage` — полноэкранная карусель с Hero, метаданные (автор, дата, бренд, группа, теги, описание), плейсхолдер счётчиков лайков/комментов под Sprint 10/11.
- [x] Маршрут `/posts/:id` в `app_router.dart` + переход с карточки `pushNamed(postDetailName)`.
- [x] Зависимость `cached_network_image: ^3.4.1` в `pubspec.yaml`.
- [x] Юнит-тесты `PostsFeedBloc` (5) + `PostDetailBloc` (4) + актуализирован `widget_test.dart` под новый `HomeView`. Всего **99 passed**, `flutter analyze` чисто, `dart format` чисто.
- [x] PR Sprint 9 → CI → ревью → мерж (PR #10).

### Sprint 10 — Likes

- [x] Like domain: `Like` entity (freezed), `LikeRepository`, 4 usecases (`LikePost`, `UnlikePost`, `WatchHasLiked`, `WatchLikers`).
- [x] Like data: `LikeDto`, `FirestoreLikeRemoteDataSource` с batched-write `posts/{id}/likes/{uid}` + `users/{uid}/likedPosts/{id}` в одной транзакции, `LikeRepositoryImpl` с маппингом `ServerException`→`ServerFailure`.
- [x] Cloud Functions `onLikeCreated` / `onLikeDeleted` инкрементируют/декрементируют `posts.likesCount` (клиент `likesCount` не трогает).
- [x] Firestore rules: `/posts/{id}/likes/{userId}` и `/users/{uid}/likedPosts/{postId}` — read под аутентификацией, create/delete только владелец, update запрещён.
- [x] `LikeButtonCubit` с оптимистичным UI: локальный `optimisticHasLiked`/`optimisticDelta`, откат при ошибке, реконсиляция со стрима.
- [x] `WhoLikedBloc` со стримом лайкеров, defended duplicate subscribe.
- [x] Виджет `LikeButton` (compact + full режимы) встроен в `PostCard` и `PostDetailPage`, переход «Кто лайкнул» → `WhoLikedPage`.
- [x] Маршрут `/posts/:id/likes` (`AppRoutes.whoLiked`) в `app_router.dart`.
- [x] Юнит-тесты `LikeRepositoryImpl` (4) + `LikeButtonCubit` (8) + `WhoLikedBloc` (3) + интеграция в общий прогон. Всего **116 passed**, `flutter analyze` чисто, `dart format` чисто.
- [x] PR Sprint 10 → CI → ревью → мерж (PR #11).

### Sprint 11 — Comments

- [x] Comment domain: `Comment` entity (freezed), `CommentRepository`, 3 usecases (`AddComment`, `DeleteComment`, `WatchComments`).
- [x] Comment data: `CommentDto`, `FirestoreCommentRemoteDataSource` (`add`/`delete`/`watch` через подколлекцию `posts/{id}/comments/{cid}`), `CommentRepositoryImpl` с маппингом `ServerException`→`ServerFailure`.
- [x] Cloud Functions `onCommentCreated` / `onCommentDeleted` инкрементируют/декрементируют `posts.commentsCount` через `FieldValue.increment(±1)`.
- [x] Firestore rules: `/posts/{id}/comments/{cid}` — read под аутентификацией, create только при `authorId == auth.uid` и `text.size() in (0, 2000]`, delete только автору, update запрещён.
- [x] `CommentsBloc` со стримом комментариев (loading/ready/error/initial), дедуп subscribe, reset.
- [x] `AddCommentCubit` для формы: text-state, clamp по `maxLength`, idle/submitting/success/error, ack-сброс.
- [x] Виджеты `CommentTile` (аватар + имя + относительное время + меню «Удалить» только для своих), `CommentInput` (TextField + кнопка отправки), `CommentsSection` (комбо: список + инпут), интегрированы в `PostDetailPage`.
- [x] Удаление через диалог-подтверждение, прямой вызов `DeleteComment` usecase.
- [x] Юнит-тесты `CommentRepositoryImpl` (5) + `CommentsBloc` (4) + `AddCommentCubit` (9) — всего **134 passed**, `flutter analyze` чисто, `dart format` чисто.
- [x] PR Sprint 11 → CI → ревью → мерж (PR #12).

### Sprint 12 — Search

- [x] `searchKeywords` токены уже пишутся в `posts/{id}` при создании / обновлении (Sprint 7) — Sprint 12 поднимает над этим поисковый слой.
- [x] Data: `PostRemoteDataSource.searchPosts` — Firestore `where(searchKeywords arrayContains)` + `orderBy(createdAt desc)`, дополнительные фильтры (rarity / brandId / groupId) применяются на клиенте, чтобы не плодить composite-индексы. `PostRepository.searchPosts` извлекает первый «значимый» (≥ 2 символов) lowercase-токен из user-input.
- [x] Domain: `SearchFilters` value-object + `SearchPosts` usecase.
- [x] Presentation: `SearchBloc` с дебаунсом 300 ms через `stream_transform.debounce + switchMap`, `SearchPage` (поисковое поле в AppBar + bottom-sheet `FiltersSheet` с RangeSlider 1–9 и текстовыми ID brand/group), переход на детальный экран `/posts/:id` через `PostCard`.
- [x] Маршрут `/search` + кнопка-поиска на `HomePage` AppBar.
- [x] Юнит-тесты `PostRepositoryImpl.searchPosts` (4) + `SearchPosts` usecase (1) + `SearchBloc` (6) — всего **145 passed**, `flutter analyze` чисто, `dart format` чисто.
- [x] PR Sprint 12 → CI → ревью → мерж (PR #13).

### Sprint 13 — Brands & Tags

- [x] Коллекция `brands` (нормализованный справочник, поле `slug` для идемпотентного поиска / создания).
- [x] Domain: `Brand` (freezed), `BrandRepository`, usecases `WatchBrands` / `WatchBrand` / `EnsureBrand` (по `slug` или create).
- [x] Data: `BrandDto` (slugify + Firestore-mapping), `FirestoreBrandRemoteDataSource`, `BrandRepositoryImpl` (Either/Failure).
- [x] Post-слой: `watchBrandFeed(brandId)` — `where(brandId == X).orderBy(rarity desc)` (composite-индекс `posts: brandId ASC + rarity DESC`).
- [x] `PostsFeedScope` расширен: `global / group(id) / brand(id)`; `PostsFeedBloc` маршрутизирует к нужному usecase.
- [x] Presentation: `BrandsBloc`, `BrandsPage` (`postsCount desc, name asc`), `BrandDetailPage` (SliverAppBar header + лента бренда), `BrandTile`, `BrandPickerSheet` (search + новый бренд).
- [x] Интеграция: кнопка «Бренды» в `HomePage` AppBar; `CreatePostPage` — выбор бренда через `BrandPickerSheet` (новый бренд проходит `EnsureBrand`); `FiltersSheet` — `brandId` через `BrandPickerSheet` вместо текстового поля.
- [x] Маршруты `/brands` и `/brands/:id` в `app_router.dart`.
- [x] Cloud Functions: `onPostCreatedUpdateBrandStats` / `onPostDeletedUpdateBrandStats` — атомарные `FieldValue.increment(±1)` на `brands/{brandId}.postsCount`.
- [x] Firestore Security Rules: `brands/{brandId}` — read for signed-in, create требует `name`/`slug`/`postsCount==0`, update — только `name/logoUrl/country/updatedAt`, delete запрещён.
- [x] Юнит-тесты: `BrandRepositoryImpl` (5), `BrandsBloc` (4), `BrandDto.slugify` (6) — всего **161 passed**, `flutter analyze` чисто, `dart format` чисто.
- [x] PR Sprint 13 → CI → ревью → мерж (PR #14).

### Sprint 14 — Barcode Scanner

- [x] Подключён `mobile_scanner` (camera permissions Android `CAMERA` + iOS `NSCameraUsageDescription`).
- [x] Domain: `Barcode` (freezed), `BarcodeRepository`, usecases `LookupBarcode` / `SaveBarcode`.
- [x] Data: `BarcodeDto` (slug-нет, документ id = сам EAN-13/UPC; `normalize()` чистит входной код от пробелов/дефисов), `FirestoreBarcodeRemoteDataSource` (lookup точечным `get`, save через идемпотентный `set(merge:true)` с `serverTimestamp()`), `BarcodeRepositoryImpl` (Either/Failure).
- [x] Presentation: `BarcodeScannerPage` (полноэкранный `MobileScanner` с overlay-рамкой и тогглом фонарика). Открывается из `CreatePostPage` через `Navigator.push`, возвращает нормализованный код.
- [x] Интеграция: `CreatePostPage` — поле «Штрих-код» с кнопкой-сканом. После скана — `LookupBarcode`. Если найдено — autofill `drinkName` + `brand`. Если нет — `state.barcode` сохраняется с флагом `barcodeContribute`, и после успешного `createPost` BLoC выполняет `SaveBarcode` (contribute-back). Расширены `CreatePostState` (`barcode`, `barcodeContribute`) и `CreatePostBloc` (события `CreatePostBarcodeMatched` / `CreatePostBarcodeUnknown` / `CreatePostBarcodeCleared`, инжектирован `SaveBarcode` usecase).
- [x] Firestore Security Rules: `barcodes/{ean}` — read for signed-in, create требует `drinkName` и `contributedBy == auth.uid`, update — только метаданные (`drinkName`, `brandId`, `brandName`, `suggestedPhotoUrl`, `contributedBy`, `createdAt`), delete запрещён.
- [x] Юнит-тесты: `BarcodeDto.normalize` (4), `BarcodeRepositoryImpl` (6), `CreatePostBloc` — barcode-редьюсеры (3) + happy-path с contribute (1) + happy-path с matched-skip (1) — всего **176 passed** (161 baseline + 15 новых), `flutter analyze` чисто, `dart format` чисто.
- [ ] PR Sprint 14 → CI → ревью → мерж.

### Sprint 15 — Profile stats & Achievements

- [ ] Cloud Function пересчёта статистики, бейджи на профиле.
- [ ] PR Sprint 15 → CI → ревью → мерж.

### Sprint 16 — Wishlist + Following

- [ ] Подколлекции `wishlist`, `following`; вкладка «Подписки» в ленте.
- [ ] PR Sprint 16 → CI → ревью → мерж.

### Sprint 17 — Push notifications

- [ ] FCM-токены в `users.fcmTokens`, Cloud Functions триггеры (новый коммент / лайк / подписчик).
- [ ] PR Sprint 17 → CI → ревью → мерж.

### Sprint 18 — Polish & Release

- [ ] Empty states, error states, skeletons, аналитика (`firebase_analytics`), Crashlytics.
- [ ] Иконки, splash, store-листинг, CD на Firebase App Distribution / Play Internal.
- [ ] PR Sprint 18 → CI → ревью → мерж.

---

## 🟦 Блок 4. CI/CD

GitHub Actions, `.github/workflows/ci.yaml`:

- **on PR в main:** `flutter pub get` → `dart format --set-exit-if-changed .` → `flutter analyze` → `flutter test`. До появления `pubspec.yaml` шаги Flutter скипаются (`if: hashFiles('pubspec.yaml') != ''`).
- **on push в main:** + сборка debug APK + загрузка артефакта.
- **release tag (v*):** деплой в Firebase App Distribution через `wzieba/Firebase-Distribution-Github-Action` (настроится в Sprint 18).

Branch protection (настроить в GitHub один раз):
- `main`: require PR, require 1 approval, require status checks to pass (CI), no force push, no deletions, automatically delete head branches after merge.

---

## 🟦 Блок 5. Git workflow (правила репозитория)

См. `CONTRIBUTING.md`. Кратко:

- Никаких коммитов в `main` напрямую.
- Каждая задача → отдельная ветка `feat/…` / `fix/…` / `chore/…` / `refactor/…` / `docs/…` / `ci/…`.
- Conventional Commits: `feat(scope): ...`, `fix(scope): ...`, и т. д.
- Squash merge в `main`, ветка автоматически удаляется после мержа.
- Никогда не коммитить секреты (`google-services.json` с приватами, `.env`, ключи).
