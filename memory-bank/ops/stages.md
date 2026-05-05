---
title: Stages And Non-Local Environments
doc_kind: engineering
doc_function: canonical
purpose: Шаблон документа по доступу к production-like окружениям. Читать при адаптации прав доступа, smoke-checks, логов и runtime-операций под проект.
derived_from:
  - ../dna/governance.md
status: active
audience: humans_and_agents
---

# Stages And Non-Local Environments

На текущем этапе первый repeatable non-local deploy path для `zenrox` зафиксирован через `Render`. Это production-like контур для MVP и Telegram webhook smoke-check, без отдельного staging-окружения. Для раннего ручного verify также допустим временный `dev+tunnel` путь, описанный в `ops/development.md`, если нужен быстрый live-check без deploy.

## Environment Inventory

| Environment | Purpose | Access path | Notes |
| --- | --- | --- | --- |
| `production` | Публичный MVP endpoint и live Telegram webhook | Render dashboard + `https://zenrox.onrender.com` | Ранний single-user runtime |

## Common Operations

Разрешенные read-only и deploy-операции раннего этапа:

```bash
curl -fsS https://<render-service>.onrender.com/up
curl -fsS -X POST https://api.telegram.org/bot<token>/setWebhook \
  -d url=https://<render-service>.onrender.com/telegram/webhook \
  -d secret_token=<secret>
curl -fsS https://api.telegram.org/bot<token>/getWebhookInfo
```

Для каждой операции зафиксируй:

- Render deploy запускается через dashboard или auto-deploy из подключенного Git-репозитория.
- Проверка health endpoint `/up` считается безопасной read-only операцией.
- `setWebhook` у Telegram является mutating-операцией во внешней системе и требует явного понимания, какой URL становится live.

## Credentials And Access

- Secrets хранятся в Render environment variables.
- Доступ к изменению переменных и ручному redeploy должен быть только у владельца проекта.
- Telegram token, optional secret token и allowed chat id не коммитятся и не дублируются в markdown значениями.
- Недопустимый обход: хранить production secrets в Git, shell history общего доступа или в `.env`, попадающем в репозиторий.

## Version And Health Checks

Задокументируй безопасные способы проверить:

- текущую deployed version;
- health endpoint;
- smoke URL;
- базовые operational dashboards.

- Health-check: `GET https://zenrox.onrender.com/up`.
- Deployed version на раннем этапе отслеживается по latest successful deploy в Render dashboard, так как version/tagging flow еще не формализован.
- Smoke URL для Telegram integration: `POST https://zenrox.onrender.com/telegram/webhook`.

## Logs And Observability

- Application logs: вкладка `Logs` у Render web service.
- Database health: Render database dashboard.
- Отдельные metrics, traces и error tracker для проекта пока не зафиксированы; это осознанный early-stage gap.

## Test Data And Smoke Targets

Для MVP используется один приватный Telegram chat, который при необходимости ограничивается через `ZENROX_TELEGRAM_ALLOWED_CHAT_ID`.

Первичный live smoke-check выполнен `2026-05-05`: production deploy доступен по `https://zenrox.onrender.com`, webhook указывает на `/telegram/webhook`, capture и retrieval сценарии в Telegram подтверждены вручную.

## Adoption Checklist

- [x] перечислены все non-local environments
- [x] указаны canonical access paths
- [x] описаны safe health/version checks
- [x] перечислены observability entrypoints
- [x] удалены фальшивые или нерелевантные примеры
