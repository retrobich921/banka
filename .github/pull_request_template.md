<!--
PR title должен следовать Conventional Commits, например:
  feat(auth): add Google sign-in usecase
  fix(posts): correct rarity slider bounds
  chore(deps): bump firebase_core to 3.6.0
-->

## Что (What)

<!-- Краткое описание изменений: какую задачу/спринт закрываем. -->

## Зачем (Why)

<!-- Зачем это нужно: связь с PROJECT_PLAN.md / issue, продуктовый эффект. -->

## Как тестировать (How to test)

<!-- Шаги для ручной проверки: что нужно открыть, нажать, проверить. -->

## Скриншоты / запись (для UI)

<!-- Если меняли UI — приложите скриншот или короткое видео. -->

## Чек-лист

- [ ] Имя ветки соответствует конвенции (`feat/`, `fix/`, `chore/`, …).
- [ ] Заголовок PR в формате Conventional Commits.
- [ ] `dart format --set-exit-if-changed .` зелёный локально.
- [ ] `flutter analyze` зелёный локально.
- [ ] `flutter test` зелёный локально (если есть тесты).
- [ ] Не закоммичены секреты (`.env`, ключи, service-account, `google-services.json` с приватами).
- [ ] Не закоммичены сгенерированные файлы (`*.g.dart`, `*.freezed.dart`).
- [ ] Соответствующие пункты в `PROJECT_PLAN.md` отмечены, если спринт закрыт.

## Связано (Related)

<!-- Sprint X / Issue # / PR # -->
