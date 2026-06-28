# Banka — Cloud Functions

Бэкэнд-логика, которая не должна крутиться на клиенте.

## Активные функции

| Функция | Триггер | Описание |
| --- | --- | --- |
| `onPostImageUploaded` | Storage finalize в `posts/**` | Собирает thumbnail 400×400 и подменяет `thumbUrl` у соответствующего фото в Firestore-документе поста. |
| `onLikeCreated` | Firestore create в `posts/{postId}/likes/{userId}` | Атомарно увеличивает счётчик `likesCount` в документе поста. |
| `onLikeDeleted` | Firestore delete в `posts/{postId}/likes/{userId}` | Атомарно уменьшает счётчик `likesCount` в документе поста. |
| `onCommentCreated` | Firestore create в `posts/{postId}/comments/{commentId}` | Атомарно увеличивает счётчик `commentsCount` в документе поста. |
| `onCommentDeleted` | Firestore delete в `posts/{postId}/comments/{commentId}` | Атомарно уменьшает счётчик `commentsCount` в документе поста. |
| `onPostCreatedUpdateBrandStats` | Firestore create в `posts/{postId}` | Атомарно увеличивает счётчик `postsCount` в документе бренда. |
| `onPostDeletedUpdateBrandStats` | Firestore delete в `posts/{postId}` | Атомарно уменьшает счётчик `postsCount` в документе бренда. |
| `onGroupDeleted` | Firestore delete в `groups/{groupId}` | Каскадное удаление: удаляет все subcollections (members, join_requests) и отвязывает посты от группы. |
| `cleanupJoinRequests` | HTTP request | Утилита для очистки старых запросов на вступление без `groupOwnerId`. |

## Деплой

```bash
cd functions
npm install
firebase deploy --only functions
```

**Примечание:** Для деплоя Cloud Functions проект должен быть на Blaze (pay-as-you-go) плане.

## Локальная отладка

```bash
firebase emulators:start --only functions,storage,firestore
```

## TODO (следующие спринты)

- Sprint 15: пересчёт статистики профиля (`stats.cansCount`, `avgRarity`, `topBrandId`).
- Sprint 17: FCM-триггеры на лайки/комменты/подписчиков.
