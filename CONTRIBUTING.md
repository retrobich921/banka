# Contributing

Этот документ — обязательные правила работы с репозиторием. Всё, что нарушает эти правила, не должно попадать в `main`.

## 1. Никаких коммитов в `main` напрямую

- Все изменения идут через Pull Request.
- `main` защищена: запрещён push без PR, запрещён force-push, запрещено удаление.
- Минимум 1 апрув + зелёный CI обязательны для мержа.

## 2. Ветки

Каждая задача = отдельная ветка от актуального `main`. Имена веток:

| Префикс     | Назначение                                          | Пример                              |
|-------------|-----------------------------------------------------|-------------------------------------|
| `feat/`     | Новая фича                                          | `feat/auth-google-sign-in`          |
| `fix/`      | Баг-фикс                                            | `fix/posts-rarity-slider-bounds`    |
| `chore/`    | Рутина (deps, configs, скрипты)                     | `chore/sprint-0-foundation`         |
| `refactor/` | Рефакторинг без изменений поведения                 | `refactor/profile-extract-stats`    |
| `docs/`     | Документация                                        | `docs/readme-setup`                 |
| `ci/`       | CI/CD                                               | `ci/actions-add-analyze`            |
| `test/`     | Тесты                                               | `test/posts-create-bloc`            |
| `perf/`     | Оптимизация без изменения функциональности          | `perf/feed-cache-thumbnails`        |
| `style/`    | Форматирование, отступы, без изменения логики       | `style/format`                      |

## 3. Conventional Commits

Каждый коммит — в формате [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

Допустимые `type`: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`, `style`, `ci`, `perf`, `build`, `revert`.

Примеры:

```
feat(auth): add Google sign-in usecase
fix(posts): correct rarity slider bounds
chore(deps): bump firebase_core to 3.6.0
refactor(profile): extract stats widget
docs(readme): add setup steps
test(posts): cover create-post bloc
ci(actions): add flutter analyze step
perf(feed): cache thumbnails
```

Breaking changes:

```
feat(auth)!: drop email/password sign-in

BREAKING CHANGE: Email/password authentication removed in favour of Google-only.
```

## 4. Workflow

1. `git checkout main && git pull` — получить актуальный `main`.
2. `git checkout -b <type>/<scope>-<short-desc>`.
3. Делать атомарные коммиты в формате Conventional Commits — один логический блок изменений = один коммит. Никаких `wip` / `fix typo` / `asdf` в истории `main`.
4. Перед PR: `dart format .`, `flutter analyze`, `flutter test` — должны быть зелёными локально.
5. Перед PR: `git fetch origin && git rebase origin/main` (не `merge`), чтобы история была линейной.
6. Открыть PR, описать **что / зачем / как тестировать**, прикрепить скриншоты для UI-изменений.
7. Дождаться зелёного CI и апрува.
8. **Squash merge** в `main`. Ветка удаляется автоматически.
9. Локально: `git checkout main && git pull && git fetch -p && git branch -d <branch>`.

## 5. Запреты

- ❌ Force-push в `main` (никогда, ни при каких условиях).
- ❌ `git commit --no-verify` без явной просьбы owner'а.
- ❌ `git commit --amend` после push в общую ветку.
- ❌ `git add .` без проверки (могут попасть лишние файлы).
- ❌ Коммитить секреты: `.env`, `google-services.json` с приватными ключами, JSON service-account, любые токены.
- ❌ Менять сгенерированные файлы вручную (`*.g.dart`, `*.freezed.dart`) — только через `build_runner`.

## 6. Pre-PR чеклист

- [ ] Линт зелёный: `dart format --set-exit-if-changed . && flutter analyze`.
- [ ] Тесты зелёные: `flutter test`.
- [ ] Нет закоммиченных секретов и сгенерированных артефактов сборки.
- [ ] PR-описание заполнено (что/зачем/как тестировать).
- [ ] Соответствующие пункты в `PROJECT_PLAN.md` отмечены как выполненные (если спринт закрыт).

## 7. Branch protection (настройка в GitHub один раз)

В `Settings → Branches → main`:

- Require a pull request before merging
- Require approvals: **1**
- Require status checks to pass before merging → выбрать workflow `CI`
- Require branches to be up to date before merging
- Do not allow bypassing the above settings
- Restrict who can push to matching branches: только owner
- Allow force pushes: **off**
- Allow deletions: **off**

В `Settings → General → Pull Requests`:

- Allow squash merging: **on** (default)
- Allow merge commits: **off**
- Allow rebase merging: **off**
- Automatically delete head branches: **on**
