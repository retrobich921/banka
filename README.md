# Banka

Социальное приложение и каталог для коллекционеров энергетических напитков.
Пользователи постят, оценивают и обсуждают банки от энергетиков, объединяются в группы/коллекции.

## Возможности

- Посты-«банки» с несколькими фото (карусель), названием, датой находки, оценкой редкости (1–9).
- Группы/коллекции, тематические подборки от пользователей.
- Лайки и комментарии под постами.
- Полноценный поиск по базе банок (название, бренд, теги).
- Авторизация через Google (Firebase Auth).
- Тёмная минималистичная тема (`#000000` + серые акценты).

## Стек

- **Flutter** (mobile-first: Android, iOS).
- **State management:** [`flutter_bloc`](https://pub.dev/packages/flutter_bloc).
- **Архитектура:** Clean Architecture (`data` / `domain` / `presentation` per feature).
- **DI:** [`get_it`](https://pub.dev/packages/get_it) + [`injectable`](https://pub.dev/packages/injectable).
- **Routing:** [`go_router`](https://pub.dev/packages/go_router).
- **Backend:** Firebase (Auth, Firestore, Storage, Functions, Messaging).

## Документы

- [PROJECT_PLAN.md](./PROJECT_PLAN.md) — продуктовый план, архитектура Firestore, Roadmap по спринтам.
- [CONTRIBUTING.md](./CONTRIBUTING.md) — Git workflow, Conventional Commits, требования к PR.

## Запуск (после Sprint 1)

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run
```

## Статус

Проект в активной разработке. Прогресс по спринтам — в [PROJECT_PLAN.md](./PROJECT_PLAN.md).

## Лицензия

См. [LICENSE](./LICENSE).
