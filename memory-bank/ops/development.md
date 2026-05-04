---
title: Development Environment
doc_kind: engineering
doc_function: canonical
purpose: Шаблон документа для локальной разработки. Читать при адаптации setup, dev-команд и browser/database workflow под проект.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Development Environment

`zenrox` использует `Rails 8`, `PostgreSQL`, `RSpec` и `mise` для выбора Ruby toolchain. Команды ниже считаются текущим локальным baseline для backend-части проекта.

Если shell уже активирован на `ruby 3.4.8` через `mise`, префикс `mise exec ruby@3.4.8 --` можно опустить. Если нет, используй его явно, чтобы не зависеть от `rbenv` или другой внешней shell-конфигурации.

## Setup

Минимальная подготовка среды:

```bash
direnv allow
mise install
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle config set path vendor/bundle
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle install
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rails db:prepare
```

## Daily Commands

Canonical локальные команды backend-разработки:

```bash
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rails server
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec
BUNDLE_APP_CONFIG=.bundle RUBOCOP_SERVER=false RUBOCOP_CACHE_ROOT=tmp/rubocop_cache mise exec ruby@3.4.8 -- bundle exec rubocop
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rails db:prepare
```

## Browser Testing

На текущем этапе у проекта нет browser-first UI. Первый MVP slice реализован как backend API, поэтому browser testing не является canonical verify path для `FT-001`.

## Database And Services

Локальные зависимости и правила:

- Нужен локально доступный `PostgreSQL`.
- Базовые имена БД: `zenrox_development`, `zenrox_test`.
- Для создания и миграций использовать `bundle exec rails db:prepare`.
- Пока не появятся новые seed-сценарии, `db/seeds.rb` не считается обязательной частью setup.
- Для `FT-001` не требуются live AI keys, Telegram credentials и другие внешние интеграции.

## Adoption Checklist

- [x] указаны реальные setup-команды
- [x] указаны реальные test/lint commands
- [x] документирован способ определения локального URL
- [x] перечислены локальные зависимости и сервисы
- [x] удалены нерелевантные примеры
