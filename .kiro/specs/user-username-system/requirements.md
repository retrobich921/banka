# Requirements Document

## Introduction

Система уникальных username для пользователей приложения Banka. Каждый пользователь получает уникальный username при первом входе через Google Sign-In, может изменить его в настройках профиля с ограничением по частоте изменений. Username заменяет displayName во всех местах приложения: в списках участников групп, комментариях, постах и профиле пользователя.

## Glossary

- **User**: Пользователь приложения, авторизованный через Firebase Auth (Google Sign-In)
- **Username**: Уникальный идентификатор пользователя в формате строки (3-20 символов, буквы, цифры, подчёркивание)
- **Username_Generator**: Компонент системы, генерирующий уникальные username на основе displayName или случайным образом
- **Username_Validator**: Компонент системы, проверяющий уникальность и формат username
- **Profile_Editor**: Компонент UI для редактирования профиля пользователя
- **User_Repository**: Репозиторий для работы с данными пользователей в Firestore
- **Auth_Service**: Сервис аутентификации Firebase Auth
- **Firestore**: База данных Cloud Firestore для хранения данных пользователей
- **DisplayName**: Имя пользователя из Google аккаунта (устаревшее, заменяется на username)
- **Username_Change_Cooldown**: Период времени (30 дней), в течение которого пользователь не может изменить username повторно
- **User_Profile_Page**: Страница профиля пользователя с информацией о публикациях и статистике

## Requirements

### Requirement 1: Автоматическая генерация username при регистрации

**User Story:** Как новый пользователь, я хочу получить уникальный username автоматически при первом входе, чтобы не тратить время на его придумывание.

#### Acceptance Criteria

1. WHEN User выполняет первый вход через Google Sign-In, THE Username_Generator SHALL сгенерировать уникальный username на основе displayName из Google аккаунта
2. IF displayName содержит недопустимые символы или уже занят, THEN THE Username_Generator SHALL сгенерировать случайный username в формате "user_" + 6 случайных цифр
3. THE Username_Generator SHALL проверить уникальность сгенерированного username через Username_Validator перед сохранением
4. WHEN username сгенерирован, THE User_Repository SHALL сохранить его в документе users/{userId} в поле "username"
5. THE сгенерированный username SHALL соответствовать формату: 3-20 символов, только латинские буквы (a-z, A-Z), цифры (0-9) и подчёркивание (_)

### Requirement 2: Валидация формата username

**User Story:** Как система, я хочу проверять формат username, чтобы обеспечить консистентность данных и предотвратить проблемы с отображением.

#### Acceptance Criteria

1. THE Username_Validator SHALL проверять, что длина username находится в диапазоне от 3 до 20 символов включительно
2. THE Username_Validator SHALL проверять, что username содержит только латинские буквы (a-z, A-Z), цифры (0-9) и символ подчёркивания (_)
3. THE Username_Validator SHALL проверять, что username не начинается с цифры
4. THE Username_Validator SHALL проверять, что username не состоит только из цифр
5. IF username не соответствует формату, THEN THE Username_Validator SHALL вернуть ошибку с описанием нарушенного правила

### Requirement 3: Проверка уникальности username

**User Story:** Как пользователь, я хочу иметь уникальный username, чтобы меня можно было однозначно идентифицировать в системе.

#### Acceptance Criteria

1. WHEN пользователь пытается установить новый username, THE Username_Validator SHALL проверить его уникальность в коллекции users
2. THE Username_Validator SHALL выполнять проверку уникальности без учёта регистра (case-insensitive)
3. IF username уже занят другим пользователем, THEN THE Username_Validator SHALL вернуть ошибку "Username уже занят"
4. THE Username_Validator SHALL разрешить пользователю сохранить свой текущий username без изменений (для случая редактирования других полей профиля)
5. THE проверка уникальности SHALL выполняться через Firestore query с использованием индекса на поле usernameLowercase

### Requirement 4: Редактирование username в профиле

**User Story:** Как пользователь, я хочу изменить свой username в настройках профиля, чтобы выбрать более подходящее имя.

#### Acceptance Criteria

1. THE Profile_Editor SHALL предоставлять текстовое поле для редактирования username
2. WHEN пользователь вводит новый username, THE Profile_Editor SHALL отображать валидацию в реальном времени (формат и уникальность)
3. WHEN пользователь сохраняет изменения, THE User_Repository SHALL проверить Username_Change_Cooldown перед сохранением
4. IF с момента последнего изменения username прошло менее 30 дней, THEN THE User_Repository SHALL вернуть ошибку "Username можно изменить только раз в 30 дней"
5. WHEN username успешно изменён, THE User_Repository SHALL обновить поле "username", "usernameLowercase" и "usernameLastChangedAt" в документе users/{userId}
6. THE Profile_Editor SHALL отображать дату следующего доступного изменения username, если cooldown активен

### Requirement 5: Ограничение частоты изменения username

**User Story:** Как система, я хочу ограничить частоту изменения username, чтобы предотвратить злоупотребления и обеспечить стабильность идентификации пользователей.

#### Acceptance Criteria

1. THE User_Repository SHALL хранить timestamp последнего изменения username в поле "usernameLastChangedAt"
2. WHEN пользователь пытается изменить username, THE User_Repository SHALL вычислить разницу между текущим временем и usernameLastChangedAt
3. IF разница меньше 30 дней (2592000 секунд), THEN THE User_Repository SHALL отклонить изменение с ошибкой
4. THE первое изменение username после автоматической генерации SHALL быть разрешено без ограничений (usernameLastChangedAt = null)
5. WHEN username изменён успешно, THE User_Repository SHALL обновить usernameLastChangedAt текущим timestamp

### Requirement 6: Замена displayName на username в UI

**User Story:** Как пользователь, я хочу видеть username вместо displayName во всех местах приложения, чтобы идентифицировать других пользователей по их уникальным именам.

#### Acceptance Criteria

1. THE приложение SHALL отображать username вместо displayName в списках участников групп (GroupMember)
2. THE приложение SHALL отображать username вместо displayName в комментариях (Comment)
3. THE приложение SHALL отображать username вместо displayName в постах (Post, поле authorName)
4. THE приложение SHALL отображать username вместо displayName на странице профиля пользователя (User_Profile_Page)
5. THE приложение SHALL отображать username вместо displayName в результатах поиска пользователей
6. IF username не установлен (legacy пользователи), THEN THE приложение SHALL отображать displayName как fallback

### Requirement 7: Обновление существующих данных

**User Story:** Как система, я хочу обновить существующие записи пользователей с username, чтобы обеспечить консистентность данных после внедрения новой функции.

#### Acceptance Criteria

1. WHEN существующий пользователь (без username) выполняет вход, THE Auth_Service SHALL проверить наличие поля username в документе users/{userId}
2. IF поле username отсутствует или пустое, THEN THE Username_Generator SHALL сгенерировать username и сохранить его
3. THE User_Repository SHALL обновить все документы GroupMember с userId пользователя, заменив displayName на username
4. THE обновление существующих данных SHALL выполняться асинхронно без блокировки UI
5. THE система SHALL логировать все операции миграции для мониторинга

### Requirement 8: Страница профиля пользователя

**User Story:** Как пользователь, я хочу видеть страницу профиля с username, публикациями и статистикой, чтобы узнать больше о других коллекционерах.

#### Acceptance Criteria

1. THE User_Profile_Page SHALL отображать username пользователя в заголовке страницы
2. THE User_Profile_Page SHALL отображать все публикации (посты) пользователя в хронологическом порядке
3. THE User_Profile_Page SHALL отображать статистику: количество постов, количество групп, количество полученных лайков
4. THE User_Profile_Page SHALL отображать среднюю редкость банок (avgRarity) и топ-бренд (topBrandId)
5. WHEN пользователь просматривает свой собственный профиль, THE User_Profile_Page SHALL отображать кнопку "Редактировать профиль"
6. WHEN пользователь просматривает чужой профиль, THE User_Profile_Page SHALL скрывать кнопку редактирования
7. THE User_Profile_Page SHALL загружать посты пользователя через запрос к коллекции posts с фильтром authorId

### Requirement 9: Индексация для поиска по username

**User Story:** Как система, я хочу эффективно искать пользователей по username, чтобы обеспечить быструю работу функции поиска.

#### Acceptance Criteria

1. THE Firestore SHALL хранить дополнительное поле "usernameLowercase" с username в нижнем регистре
2. WHEN username обновляется, THE User_Repository SHALL автоматически обновлять поле usernameLowercase
3. THE поиск пользователей SHALL использовать запрос по полю usernameLowercase для case-insensitive поиска
4. THE Firestore SHALL иметь индекс на поле usernameLowercase для оптимизации запросов
5. THE поиск по username SHALL поддерживать префиксный поиск (startsWith) для автодополнения

### Requirement 10: Обработка ошибок при работе с username

**User Story:** Как пользователь, я хочу получать понятные сообщения об ошибках при работе с username, чтобы понимать, что пошло не так и как это исправить.

#### Acceptance Criteria

1. IF Username_Validator обнаруживает невалидный формат, THEN THE система SHALL отобразить сообщение "Username должен содержать 3-20 символов: буквы, цифры, подчёркивание"
2. IF Username_Validator обнаруживает занятый username, THEN THE система SHALL отобразить сообщение "Username уже занят, выберите другой"
3. IF User_Repository обнаруживает активный cooldown, THEN THE система SHALL отобразить сообщение "Username можно изменить только раз в 30 дней. Следующее изменение доступно: {дата}"
4. IF Username_Generator не может сгенерировать уникальный username после 10 попыток, THEN THE система SHALL отобразить сообщение "Не удалось сгенерировать username, попробуйте позже"
5. THE все сообщения об ошибках SHALL отображаться на русском языке в соответствии с локалью приложения

### Requirement 11: Миграция данных GroupMember

**User Story:** Как система, я хочу обновить поле displayName в документах GroupMember на username, чтобы обеспечить консистентность отображения участников групп.

#### Acceptance Criteria

1. WHEN username пользователя изменяется, THE User_Repository SHALL найти все документы groups/{groupId}/members/{userId} с этим userId
2. THE User_Repository SHALL обновить поле displayName в найденных документах GroupMember на новый username
3. THE обновление документов GroupMember SHALL выполняться в batch-операции для оптимизации производительности
4. IF batch-операция превышает лимит Firestore (500 операций), THEN THE User_Repository SHALL разбить обновление на несколько batch'ей
5. THE User_Repository SHALL логировать количество обновлённых документов GroupMember для мониторинга

### Requirement 12: Денормализация username в постах и комментариях

**User Story:** Как система, я хочу хранить username в постах и комментариях для быстрого отображения без дополнительных запросов к коллекции users.

#### Acceptance Criteria

1. WHEN пользователь создаёт пост, THE Post_Repository SHALL сохранить username в поле authorName документа posts/{postId}
2. WHEN пользователь создаёт комментарий, THE Comment_Repository SHALL сохранить username в поле authorName документа posts/{postId}/comments/{commentId}
3. WHEN username пользователя изменяется, THE система SHALL обновить поле authorName во всех постах пользователя
4. WHEN username пользователя изменяется, THE система SHALL обновить поле authorName во всех комментариях пользователя
5. THE обновление денормализованных данных SHALL выполняться асинхронно через Cloud Function для минимизации задержки UI
6. THE Cloud Function SHALL использовать batch-операции для обновления большого количества документов

