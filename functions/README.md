# Banka — Cloud Functions

Бэкэнд-логика, которая не должна крутиться на клиенте.

## Активные функции

| Функция | Триггер | Описание |
| --- | --- | --- |
| `onPostImageUploaded` | Storage finalize в `posts/**` | Собирает thumbnail 400×400 и подменяет `thumbUrl` у соответствующего фото в Firestore-документе поста. |

## Деплой

```bash
cd functions
npm install
firebase deploy --only functions
```

## Локальная отладка

```bash
firebase emulators:start --only functions,storage,firestore
```

## TODO (следующие спринты)

- Sprint 10: `onLikeWritten` — атомарный счётчик `likesCount`.
- Sprint 11: `onCommentWritten` — счётчик `commentsCount`.
- Sprint 15: пересчёт статистики профиля (`stats.cansCount`, `avgRarity`, `topBrandId`).
- Sprint 17: FCM-триггеры на лайки/комменты/подписчиков.
