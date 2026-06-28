# Tech Stack

## Core Technologies

- **Flutter**: 3.35+ (channel stable)
- **Dart**: 3.11+
- **Platform**: Android + iOS

## State Management & Architecture

- **Pattern**: Clean Architecture per feature
- **State**: `flutter_bloc` + `bloc` (sealed events, Equatable state)
- **DI**: `get_it` + `injectable` (codegen в `injector.config.dart`)
- **Routing**: `go_router`
- **Functional**: `dartz` — `Either<Failure, T>` на границе data → domain

## Data & Models

- **Models**: `freezed` + `json_serializable` (codegen)
- **Utilities**: `equatable` для value equality

## Backend (Firebase)

- **Auth**: `firebase_auth` + `google_sign_in`
- **Database**: `cloud_firestore`
- **Storage**: `firebase_storage`
- **Functions**: Node 20, region `europe-west3`
- **Messaging**: `firebase_messaging`

## Media & Scanning

- **Image Picker**: `image_picker`
- **Image Processing**: `image` (компрессия JPEG q=85, ≤1600px)
- **Caching**: `cached_network_image`
- **Barcode Scanner**: `mobile_scanner` (EAN-13/UPC/EAN-8)

## Utilities

- **Search**: `stream_transform` (debounce поискового ввода)
- **Paths**: `path`, `path_provider`
- **i18n**: `intl` (русская локаль `ru_RU`)
- **HTTP**: `http` (для Cloudinary, если используется)

## Dev Dependencies

- **Linting**: `flutter_lints` (через `analysis_options.yaml`)
- **Codegen**: `build_runner`, `freezed`, `injectable_generator`, `json_serializable`
- **Testing**: `flutter_test`, `bloc_test`, `mocktail`

## Common Commands

### Setup & Codegen

```bash
# Установка зависимостей
flutter pub get

# Кодогенерация (freezed, json_serializable, injectable)
dart run build_runner build

# Очистка перед кодогенерацией (при конфликтах)
dart run build_runner clean
dart run build_runner build
```

### Quality Gates

```bash
# Анализ кода (должен быть 0 issues)
flutter analyze

# Форматирование (должен быть 0 changed)
dart format --set-exit-if-changed .

# Запуск тестов
flutter test

# Тесты с coverage
flutter test --coverage
```

### Build & Run

```bash
# Debug-сборка с hot reload
flutter run

# Release-сборка
flutter run --release

# Сборка APK
flutter build apk --release

# Установка APK на устройство
flutter install

# Логи
flutter logs
adb logcat -s flutter:*
```

### Firebase

```bash
# Конфигурация Firebase
flutterfire configure --project=banka-collectors-app

# Деплой Rules и индексов
firebase deploy --only firestore:rules,firestore:indexes

# Деплой Cloud Functions
cd functions
npm install
firebase deploy --only functions
```

### Device Management

```bash
# Проверка подключённых устройств
adb devices
flutter devices

# Очистка сборки
flutter clean
```

## Build Requirements

- **Java JDK**: 17 (для Android Gradle 8.x)
- **Android SDK**: API 34 + latest build-tools
- **Xcode**: 15+ (только для iOS)
- **Node.js**: 20.x (для Cloud Functions)
- **Firebase CLI**: `firebase-tools` ≥ 13
- **FlutterFire CLI**: `dart pub global activate flutterfire_cli`

## CI/CD

GitHub Actions (`.github/workflows/ci.yaml`):
- **On PR**: `flutter analyze` + `dart format` + `flutter test`
- **On push to main**: + debug APK artifact
- **On release tag**: Firebase App Distribution (Sprint 18)
