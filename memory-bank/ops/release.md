---
title: Release And Deployment
doc_kind: engineering
doc_function: canonical
purpose: Шаблон документа релизного процесса. Читать при адаптации versioning, changelog, deployment и release verification под проект.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Release And Deployment

Первый repeatable release path для `zenrox` зафиксирован через `Render Blueprint` из файла [`render.yaml`](../../../render.yaml). Production-like MVP service уже поднят на `https://zenrox.onrender.com`. Это ранний flow без staging и без отдельного CI pipeline.

## Release Flow

1. bump версии;
2. прогон локальных `RSpec` и boot-check;
3. push в подключенный Git remote;
4. Render auto-deploy web service и применяет `buildCommand` из `render.yaml`;
5. во время build выполняется `bundle exec rails db:migrate`;
6. проверить `GET /up` на `https://zenrox.onrender.com/up` и Telegram webhook smoke;
7. при первом deploy или смене URL обновить webhook через Telegram Bot API.

## Release Commands

Canonical команды и safety rules раннего этапа:

```bash
BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec
curl -fsS https://<render-service>.onrender.com/up
curl -fsS -X POST https://api.telegram.org/bot<token>/setWebhook \
  -d url=https://<render-service>.onrender.com/telegram/webhook \
  -d secret_token=<secret>
curl -fsS https://api.telegram.org/bot<token>/getWebhookInfo
```

Укажи явно:

- Обязательные production env vars: `DATABASE_URL`, `SECRET_KEY_BASE`, `ZENROX_TELEGRAM_BOT_TOKEN`.
- Условно обязательные для безопасного single-user rollout: `ZENROX_TELEGRAM_SECRET_TOKEN`, `ZENROX_TELEGRAM_ALLOWED_CHAT_ID`.
- Render deploy может быть automated через Git push, но смена webhook URL остается manual step.
- Отдельного approval workflow для production пока не автоматизировано; это early-stage operational gap.
- Первый live deploy и webhook registration подтверждены для `https://zenrox.onrender.com` датой `2026-05-05`.

## Release Test Plan

При каждом заметном MVP-изменении полезно создавать короткий release smoke plan, даже если formal versioning еще не введен.

**Формат:** `release-v{VERSION}-test-plan.md`

**Минимальная структура:**

```markdown
# Тестовый план релиза v{VERSION}

**Дата:** YYYY-MM-DD
**Предыдущая версия:** v{PREV_VERSION}
**Текущая версия:** v{VERSION}
**Стенд:** <environment>

## Обзор изменений

| Issue | Название | Тип | Приоритет |
| --- | --- | --- | --- |
| #XXXX | Описание задачи | Feature/Fix/Refactoring/Tech debt | Высокий/Средний/Низкий |

## Проверка изменений

- [ ] Описан хотя бы один test case для каждого крупного change set

## Smoke-тесты

- [ ] Главная страница открывается
- [ ] Основной пользовательский поток работает
- [ ] Админский или внутренний путь работает
- [ ] Health endpoint отвечает успешно
```

## Rollback

- Rollback unit: предыдущий успешный deploy в Render.
- Fastest safe rollback: redeploy previous commit в Render dashboard.
- Если текущий deploy включал миграцию со schema change, rollback должен считаться отдельно от кода; пока в проекте нет documented reversible migration policy beyond standard Rails migrations.
- Telegram webhook после rollback должен по-прежнему указывать на актуальный production URL; если URL не менялся, повторный `setWebhook` не требуется.
