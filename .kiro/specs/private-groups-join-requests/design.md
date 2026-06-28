# Private Groups Join Requests Bugfix Design

## Overview

Владельцы закрытых групп не могут одобрять запросы на вступление из-за ограничений Firestore Security Rules. При одобрении запроса метод `approveJoinRequest` вызывает `joinGroup`, который пытается создать member-документ для другого пользователя. Security Rules блокируют эту операцию, так как правило `allow create: if isSelf(memberId)` требует, чтобы создатель документа совпадал с `memberId`.

**Стратегия исправления:** Расширить Security Rules для подколлекции `members`, добавив исключение для владельца группы. Владелец сможет создавать member-документы для других пользователей (при одобрении запросов), сохраняя защиту от злоупотреблений для обычных пользователей.

## Glossary

- **Bug_Condition (C)**: Условие, при котором проявляется баг - владелец группы пытается одобрить запрос на вступление, вызывая создание member-документа для другого пользователя
- **Property (P)**: Желаемое поведение - владелец группы должен иметь возможность создавать member-документы для пользователей при одобрении запросов
- **Preservation**: Существующее поведение самостоятельного вступления/выхода пользователей, которое должно остаться неизменным
- **approveJoinRequest**: Метод в `GroupRemoteDataSource`, который одобряет запрос на вступление и добавляет пользователя в группу
- **joinGroup**: Метод в `GroupRemoteDataSource`, который создаёт member-документ и обновляет денормализованные поля группы
- **isSelf(memberId)**: Helper-функция в Security Rules, проверяющая совпадение `request.auth.uid` с `memberId`
- **isGroupOwner(groupId)**: Новая helper-функция, которая проверяет, является ли текущий пользователь владельцем группы

## Bug Details

### Bug Condition

Баг проявляется, когда владелец группы пытается одобрить запрос на вступление другого пользователя. Метод `approveJoinRequest` вызывает `joinGroup` с параметром `userId` (ID пользователя, который хочет вступить), но Security Rules блокируют создание member-документа, так как `request.auth.uid` (владелец) не совпадает с `memberId` (вступающий пользователь).

**Formal Specification:**
```
FUNCTION isBugCondition(input)
  INPUT: input of type { operation: string, groupId: string, memberId: string, authUid: string }
  OUTPUT: boolean
  
  RETURN input.operation == 'create_member'
         AND isGroupOwner(input.groupId, input.authUid)
         AND input.authUid != input.memberId
         AND NOT memberDocumentCreated(input.groupId, input.memberId)
END FUNCTION
```

### Examples

- **Пример 1**: Владелец (uid: "owner123") одобряет запрос пользователя (uid: "user456") на вступление в группу "group789"
  - **Ожидается**: Member-документ `groups/group789/members/user456` создаётся успешно
  - **Фактически**: Firestore выдаёт ошибку "The caller does not have permission to execute the specified operation"

- **Пример 2**: Владелец (uid: "alice") одобряет запрос пользователя (uid: "bob") на вступление в закрытую группу "private-collectors"
  - **Ожидается**: Bob добавляется в группу, его member-документ создаётся, счётчики обновляются
  - **Фактически**: Операция блокируется на этапе создания member-документа

- **Пример 3**: Пользователь (uid: "charlie") самостоятельно вступает в публичную группу
  - **Ожидается**: Member-документ создаётся успешно (существующее поведение)
  - **Фактически**: Работает корректно (не затронуто багом)

- **Edge case**: Владелец пытается одобрить запрос для пользователя, который уже является участником
  - **Ожидается**: Операция должна быть идемпотентной или выдавать понятную ошибку

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Обычные пользователи могут самостоятельно вступать в публичные группы (создавать собственный member-документ)
- Пользователи могут самостоятельно выходить из групп (удалять собственный member-документ)
- Владелец группы может изменять роли участников (обновлять member-документы)
- Обычные пользователи НЕ могут создавать member-документы для других пользователей (защита от злоупотреблений)
- Создание запросов на вступление работает только для самого пользователя
- Обновление статуса запроса доступно только владельцу группы

**Scope:**
Все операции, которые НЕ связаны с одобрением запросов владельцем группы, должны остаться полностью неизменными. Это включает:
- Самостоятельное вступление пользователей в публичные группы
- Выход пользователей из групп
- Создание и удаление запросов на вступление
- Обновление ролей участников владельцем

## Hypothesized Root Cause

На основе анализа кода и Security Rules, корневая причина бага:

1. **Слишком строгое правило создания member-документов**: Текущее правило `allow create: if isSelf(memberId)` разрешает создание member-документа только самому пользователю. Это правило не учитывает сценарий, когда владелец группы должен добавить другого пользователя при одобрении запроса.

2. **Отсутствие исключения для владельца группы**: Security Rules не содержат логики, которая бы разрешала владельцу группы создавать member-документы для других пользователей. Проверка `isSelf(memberId)` всегда возвращает `false`, когда владелец пытается создать документ для другого пользователя.

3. **Архитектурное решение использовать клиентский код**: Метод `approveJoinRequest` вызывает `joinGroup` на клиенте, что требует прохождения Security Rules. Альтернативный подход (Cloud Function с admin SDK) обошёл бы эту проблему, но потребовал бы изменения архитектуры.

4. **Недостаточная гранулярность правил**: Правило не различает контекст создания member-документа (самостоятельное вступление vs одобрение владельцем), что приводит к блокировке легитимной операции.

## Correctness Properties

Property 1: Bug Condition - Owner Can Approve Join Requests

_For any_ operation where the group owner attempts to create a member document for another user (when approving a join request), the fixed Security Rules SHALL allow the creation if the requester is the group owner, enabling successful approval of join requests.

**Validates: Requirements 2.1, 2.2, 2.3**

Property 2: Preservation - Self-Join and Self-Leave Behavior

_For any_ operation where a user creates or deletes their own member document (self-join or self-leave), the fixed Security Rules SHALL produce exactly the same behavior as the original rules, preserving the ability for users to independently join public groups and leave any group.

**Validates: Requirements 3.1, 3.2**

Property 3: Preservation - Protection Against Unauthorized Member Creation

_For any_ operation where a non-owner user attempts to create a member document for another user, the fixed Security Rules SHALL continue to block the operation, preserving protection against unauthorized member additions.

**Validates: Requirements 3.3**

## Fix Implementation

### Changes Required

Assuming our root cause analysis is correct:

**File**: `firestore.rules`

**Section**: `match /groups/{groupId}` → `match /members/{memberId}`

**Specific Changes**:

1. **Добавить helper-функцию для проверки владельца группы**:
   - Создать функцию `isGroupOwner(groupId)` в секции helpers
   - Функция должна использовать `get()` для чтения документа группы и проверки `ownerId`
   - Пример: `function isGroupOwner(groupId) { return isSignedIn() && get(/databases/$(database)/documents/groups/$(groupId)).data.ownerId == request.auth.uid; }`

2. **Расширить правило `allow create` для member-документов**:
   - Изменить `allow create: if isSelf(memberId);` на `allow create: if isSelf(memberId) || isGroupOwner(groupId);`
   - Это разрешит создание member-документа либо самому пользователю (существующее поведение), либо владельцу группы (новое поведение для одобрения запросов)

3. **Сохранить существующие правила для update и delete**:
   - Правило `allow delete: if isSelf(memberId);` остаётся без изменений (пользователи могут выходить из групп)
   - Правило `allow update: if isSignedIn() && get(...).data.ownerId == request.auth.uid;` остаётся без изменений (владелец может менять роли)

4. **Добавить комментарий для ясности**:
   - Добавить комментарий, объясняющий, что владелец может создавать member-документы при одобрении запросов на вступление

### Pseudocode for Fixed Rule

```
// Helper function
function isGroupOwner(groupId) {
  return isSignedIn() 
    && get(/databases/$(database)/documents/groups/$(groupId)).data.ownerId == request.auth.uid;
}

// In members subcollection
match /members/{memberId} {
  allow read: if isSignedIn();
  
  // Пользователь может создать собственный member-документ (вступить в публичную группу)
  // ИЛИ владелец группы может создать member-документ для другого пользователя
  // (при одобрении запроса на вступление)
  allow create: if isSelf(memberId) || isGroupOwner(groupId);
  
  // Пользователь может удалить собственный member-документ (выйти из группы)
  allow delete: if isSelf(memberId);
  
  // Владелец группы может изменять роли участников
  allow update: if isSignedIn()
    && get(/databases/$(database)/documents/groups/$(groupId)).data.ownerId == request.auth.uid;
}
```

## Testing Strategy

### Validation Approach

Стратегия тестирования следует двухфазному подходу: сначала демонстрируем баг на неисправленном коде (exploratory testing), затем проверяем, что исправление работает корректно и сохраняет существующее поведение (fix checking и preservation checking).

### Exploratory Bug Condition Checking

**Goal**: Продемонстрировать баг ДО внесения изменений в Security Rules. Подтвердить или опровергнуть анализ корневой причины. Если опровергнем, потребуется пересмотр гипотезы.

**Test Plan**: Написать интеграционные тесты, которые симулируют сценарий одобрения запроса владельцем группы. Запустить тесты на НЕИСПРАВЛЕННЫХ Security Rules, чтобы наблюдать ошибку и подтвердить корневую причину.

**Test Cases**:
1. **Owner Approves Join Request Test**: Владелец создаёт закрытую группу, пользователь отправляет запрос, владелец одобряет запрос (будет падать на неисправленных правилах с ошибкой permission denied)
2. **Owner Creates Member Directly Test**: Владелец пытается напрямую создать member-документ для другого пользователя через `joinGroup` (будет падать на неисправленных правилах)
3. **User Self-Join Public Group Test**: Пользователь самостоятельно вступает в публичную группу (должен работать на неисправленных правилах - это не баг)
4. **Non-Owner Creates Member for Another Test**: Обычный пользователь пытается создать member-документ для другого пользователя (должен блокироваться на неисправленных правилах - это защита)

**Expected Counterexamples**:
- Тесты 1 и 2 должны падать с ошибкой "permission-denied" или "The caller does not have permission"
- Возможные причины: правило `isSelf(memberId)` блокирует владельца, отсутствует проверка `isGroupOwner`

### Fix Checking

**Goal**: Проверить, что для всех входных данных, где выполняется условие бага, исправленные Security Rules производят ожидаемое поведение.

**Pseudocode:**
```
FOR ALL input WHERE isBugCondition(input) DO
  result := createMemberDocument_fixed(input)
  ASSERT expectedBehavior(result)
END FOR
```

**Testing Approach**: После внесения изменений в Security Rules запустить тесты, которые проверяют:
- Владелец может успешно одобрить запрос на вступление
- Member-документ создаётся для другого пользователя
- Денормализованные поля группы обновляются корректно
- Статус запроса меняется на "approved"

**Test Cases**:
1. **Owner Approves Join Request - Success**: Владелец одобряет запрос, пользователь добавляется в группу
2. **Owner Approves Multiple Requests**: Владелец одобряет несколько запросов подряд
3. **Owner Approves Request for Already Member**: Владелец пытается одобрить запрос для пользователя, который уже в группе (проверка идемпотентности)

### Preservation Checking

**Goal**: Проверить, что для всех входных данных, где условие бага НЕ выполняется, исправленные Security Rules производят тот же результат, что и оригинальные правила.

**Pseudocode:**
```
FOR ALL input WHERE NOT isBugCondition(input) DO
  ASSERT originalRules(input) = fixedRules(input)
END FOR
```

**Testing Approach**: Property-based testing рекомендуется для preservation checking, так как:
- Автоматически генерирует множество тестовых случаев по всему домену входных данных
- Находит граничные случаи, которые могут быть упущены в ручных unit-тестах
- Даёт сильные гарантии, что поведение не изменилось для всех не-багованных входных данных

**Test Plan**: Наблюдать поведение на НЕИСПРАВЛЕННЫХ правилах для операций самостоятельного вступления/выхода, затем написать property-based тесты, фиксирующие это поведение.

**Test Cases**:
1. **User Self-Join Preservation**: Наблюдать, что пользователь может вступить в публичную группу на неисправленных правилах, затем написать тест, проверяющий, что это продолжает работать после исправления
2. **User Self-Leave Preservation**: Наблюдать, что пользователь может выйти из группы на неисправленных правилах, затем написать тест, проверяющий сохранение этого поведения
3. **Non-Owner Cannot Create Member Preservation**: Наблюдать, что обычный пользователь не может создать member-документ для другого на неисправленных правилах, затем написать тест, проверяющий сохранение этой защиты
4. **Owner Can Update Member Role Preservation**: Наблюдать, что владелец может менять роли участников на неисправленных правилах, затем написать тест, проверяющий сохранение этого поведения
5. **Join Request Creation Preservation**: Наблюдать, что пользователь может создать запрос только для себя на неисправленных правилах, затем написать тест, проверяющий сохранение этого ограничения

### Unit Tests

- Тест helper-функции `isGroupOwner(groupId)` с различными сценариями (владелец, не владелец, несуществующая группа)
- Тест правила `allow create` для member-документов с различными комбинациями (self-join, owner-join, non-owner-join)
- Тест правила `allow delete` для member-документов (self-leave, owner-leave, non-owner-leave)
- Тест правила `allow update` для member-документов (owner updates role, non-owner tries to update)

### Property-Based Tests

- Генерировать случайные комбинации (groupId, ownerId, memberId, authUid) и проверять, что правила создания member-документов работают корректно
- Генерировать случайные сценарии вступления/выхода и проверять, что поведение сохраняется после исправления
- Тестировать, что все операции, не связанные с одобрением запросов владельцем, продолжают работать одинаково

### Integration Tests

- Полный flow: создание закрытой группы → отправка запроса → одобрение владельцем → проверка членства
- Полный flow: создание публичной группы → самостоятельное вступление → проверка членства
- Полный flow: вступление в группу → выход из группы → проверка отсутствия членства
- Тест переключения между контекстами: пользователь отправляет запрос в несколько групп, владельцы одобряют в разном порядке
- Тест визуальной обратной связи: после одобрения запроса UI обновляется корректно (список запросов, список участников)
