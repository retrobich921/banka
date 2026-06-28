# Bugfix Requirements Document

## Introduction

Пользователи не могут вступить в закрытые группы из-за ошибки прав доступа при одобрении запроса владельцем. Когда владелец группы пытается одобрить запрос на вступление, система выдаёт ошибку "The caller does not have permission to execute the specified operation". Это блокирует основной сценарий использования закрытых групп.

**Контекст:**
- Flutter приложение для коллекции энергетических напитков
- Backend: Firebase (Firestore, Auth, Storage)
- Архитектура: Clean Architecture
- Запросы на вступление хранятся в `groups/{groupId}/join_requests/{userId}`
- При одобрении запроса пользователь должен быть добавлен в группу через метод `joinGroup`

**Воспроизведение:**
1. Пользователь A создаёт закрытую группу (isPublic = false)
2. Пользователь B отправляет запрос на вступление
3. Пользователь A видит запрос в списке запросов
4. Пользователь A нажимает "Принять"
5. **Результат:** Ошибка "The caller does not have permission to execute the specified operation"

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN владелец группы одобряет запрос на вступление (вызывается `approveJoinRequest`) THEN система выдаёт ошибку "The caller does not have permission to execute the specified operation" и пользователь не добавляется в группу

1.2 WHEN метод `approveJoinRequest` пытается вызвать `joinGroup` для добавления пользователя в группу THEN Firestore Security Rules блокируют операцию из-за несоответствия `request.auth.uid` и `userId` в запросе

1.3 WHEN владелец пытается обновить документ `groups/{groupId}/members/{userId}` для другого пользователя THEN Security Rules запрещают создание member-документа, так как проверка `isSelf(memberId)` не проходит

### Expected Behavior (Correct)

2.1 WHEN владелец группы одобряет запрос на вступление THEN система SHALL успешно добавить пользователя в группу без ошибок прав доступа

2.2 WHEN метод `approveJoinRequest` вызывает операции для добавления пользователя в группу THEN Firestore Security Rules SHALL разрешить владельцу группы создавать member-документы для других пользователей

2.3 WHEN владелец группы одобряет запрос THEN система SHALL обновить статус запроса на "approved", добавить пользователя в подколлекцию `members`, обновить массив `membersUids` и инкрементировать `membersCount`

### Unchanged Behavior (Regression Prevention)

3.1 WHEN обычный пользователь пытается самостоятельно вступить в публичную группу THEN система SHALL CONTINUE TO разрешать создание собственного member-документа через `isSelf(memberId)`

3.2 WHEN обычный пользователь пытается самостоятельно выйти из группы THEN система SHALL CONTINUE TO разрешать удаление собственного member-документа

3.3 WHEN пользователь пытается создать member-документ для другого пользователя (не через одобрение запроса владельцем) THEN система SHALL CONTINUE TO блокировать эту операцию

3.4 WHEN владелец группы изменяет роль участника THEN система SHALL CONTINUE TO разрешать обновление member-документа

3.5 WHEN пользователь создаёт запрос на вступление в закрытую группу THEN система SHALL CONTINUE TO разрешать создание документа `join_requests/{userId}` только для самого пользователя

3.6 WHEN владелец группы обновляет статус запроса (одобряет/отклоняет) THEN система SHALL CONTINUE TO разрешать обновление документа запроса по проверке `groupOwnerId`

3.7 WHEN пользователь или владелец удаляет запрос на вступление THEN система SHALL CONTINUE TO разрешать удаление по существующим правилам
