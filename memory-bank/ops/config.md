---
title: Configuration Guide
doc_kind: engineering
doc_function: canonical
purpose: Шаблон документа ownership-модели конфигурации. Читать при описании env contract, naming conventions и config sources проекта.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Configuration Guide

Этот документ не обязан перечислять все переменные окружения подряд. Его задача: объяснить, где живет canonical schema конфигурации и как downstream-проект документирует важные настройки.

Для `zenrox` конфигурация пока не адаптирована до конкретного runtime layout, поэтому ниже фиксируется ownership-модель раннего этапа, а не окончательный env contract.

## Configuration Architecture

На текущем этапе допустима простая конфигурационная модель вида `.env` / runtime env vars плюс application-level config adapter. После выбора стека эта модель должна быть уточнена, но уже сейчас действуют такие ownership rules:

- должен существовать один config owner-слой, через который приложение читает AI provider settings, Telegram credentials, reminder-related settings и storage/runtime configuration;
- business/domain код не должен читать сырые env vars напрямую;
- defaults и feature flags должны жить рядом с config owner-слоем, а не быть размазанными по модулям;
- изменения integration contract сначала отражаются в config owner, затем в этом документе и связанных ops docs.

### Configuration Domains

- `AI provider` — модель/провайдер, credentials, лимиты и cost-sensitive настройки.
- `Telegram / client delivery` — bot token, delivery-related identifiers и client-facing integration settings.
- `Reminder runtime` — timezone assumptions, scheduling knobs, retry/delivery policy, если она появится в коде.
- `Storage / persistence` — база данных, файловое хранилище или другой source of truth для personal memory.
- `Feature flags / rollout controls` — временные переключатели для risky behavior, если такие появятся.

### Ownership Rules

Для раннего этапа `zenrox` уже действуют следующие правила:

1. schema-owner конфигурации должен быть один, даже если физически переменные пока задаются просто через `.env` или shell env.
2. secrets не коммитятся в репозиторий и не дублируются в markdown-документах.
3. AI credentials и Telegram credentials считаются разными конфигурационными доменами и должны документироваться раздельно.
4. reminder-related настройки считаются runtime-critical: их нельзя прятать в произвольных helper constants.
5. cost-sensitive параметры внешнего AI должны быть видимы и централизованы, потому что стоимость является product constraint.

## Naming Convention For Env Vars

Для текущего Rails baseline `zenrox` использует префикс `ZENROX_` для project-owned runtime settings.

- AI, Telegram и reminder-related переменные должны быть распознаваемы по имени как принадлежащие к разным доменам;
- project-owned secrets и integration settings используют uppercase snake case;
- после появления новых runtime-critical переменных они должны добавляться в соответствующий domain этого документа.

## Documenting Important Variables

Текущий concrete env contract раннего этапа:

| Variable | Domain | Required | Purpose |
| --- | --- | --- | --- |
| `DATABASE_URL` | Storage / persistence | yes for Render production | Полная строка подключения к production PostgreSQL, canonical PaaS contract |
| `ZENROX_DATABASE_PASSWORD` | Storage / persistence | no | Пароль для PostgreSQL, если локальная БД требует auth |
| `SECRET_KEY_BASE` | Platform / Rails runtime | yes for production | Секрет Rails для production boot и подписи framework internals |
| `RAILS_MAX_THREADS` | Platform / Rails runtime | no | Размер thread pool Puma и Active Record pool baseline |
| `WEB_CONCURRENCY` | Platform / Rails runtime | no | Число Puma workers для PaaS runtime |
| `ZENROX_TELEGRAM_BOT_TOKEN` | Telegram / client delivery | yes for live Telegram | Bot token для исходящей отправки reply и live webhook path |
| `ZENROX_TELEGRAM_SECRET_TOKEN` | Telegram / client delivery | no | Secret header guard для `X-Telegram-Bot-Api-Secret-Token` |
| `ZENROX_TELEGRAM_ALLOWED_CHAT_ID` | Telegram / client delivery | no | Optional allow-list для единственного приватного чата early-stage single-user setup |

Если появляется новый runtime-critical конфигурационный контракт, он должен быть добавлен в один из доменов:

- AI provider access
- Telegram client delivery
- Reminder runtime
- Storage/persistence
- Feature flags and rollout controls

## Secrets

- Никогда не вставляй реальные значения секретов в репозиторий.
- Документируй только способ их хранения, выдачи и rotation policy.
- Если часть конфигурации приходит из secret manager, это должно быть написано явно.
- Пока secret manager не выбран, допустимо локальное хранение секретов вне репозитория через shell env или локальный `.env`, если файл исключен из version control.

## Adoption Checklist

- [x] описан schema-owner конфигурации на уровне ownership model
- [x] задокументирована naming convention после выбора runtime stack
- [x] перечислены ключевые runtime/env domains
- [x] описан secret handling
- [x] удалены ссылки на несуществующие downstream-справочники
