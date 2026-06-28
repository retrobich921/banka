# Пересчёт счётчика постов для брендов

## Проблема
Счётчик `brands/{brandId}.postsCount` обновляется только для новых постов через Cloud Functions. Для существующих постов счётчик может быть неправильным.

## Решение
Запустить скрипт `recalculate_brands.js`, который пересчитает счётчики для всех брендов.

## Инструкция

### 1. Скачать Service Account Key

1. Открыть [Firebase Console](https://console.firebase.google.com/project/banka-collectors-app/settings/serviceaccounts/adminsdk)
2. Перейти в **Project Settings** → **Service Accounts**
3. Нажать **Generate New Private Key**
4. Сохранить файл как `functions/serviceAccountKey.json`

⚠️ **ВАЖНО:** Файл `serviceAccountKey.json` содержит приватные ключи! Не коммитить в Git!

### 2. Установить зависимости (если ещё не установлены)

```bash
cd functions
npm install
```

### 3. Запустить скрипт

```bash
node recalculate_brands.js
```

### 4. Проверить результат

Скрипт выведет:
- Список обновлённых брендов с изменениями счётчика
- Список пропущенных брендов (у которых счётчик уже правильный)
- Итоговую статистику

## Пример вывода

```
Starting brand posts count recalculation...
Found 15 brands
✓ Updated brand "Red Bull" (brand_123): 0 → 42
✓ Updated brand "Monster" (brand_456): 5 → 38
- Skipped brand "Burn" (brand_789): already correct (12)
...

✅ Recalculation completed!
   Updated: 10 brands
   Skipped: 5 brands (already correct)
```

## Когда запускать

- После миграции данных
- После импорта постов
- Если заметили неправильные счётчики в UI
- После исправления багов в Cloud Functions

## Безопасность

- Скрипт только **читает** посты и **обновляет** счётчики брендов
- Не удаляет и не изменяет посты
- Можно запускать многократно (идемпотентный)
