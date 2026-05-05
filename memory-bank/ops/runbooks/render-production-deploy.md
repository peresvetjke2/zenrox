---
title: Render Production Deploy
doc_kind: engineering
doc_function: canonical
purpose: Пошаговая инструкция по production deploy `zenrox` на Render и live Telegram webhook smoke-check.
derived_from:
  - ../release.md
  - ../stages.md
  - ../config.md
status: active
audience: humans_and_agents
---

# Render Production Deploy

## Summary

Runbook покрывает повторяемый deploy Rails-приложения `zenrox` на Render, обновление Telegram webhook и минимальный live smoke-check для capture/retrieval loop.

## Trigger / Symptoms

- первый production deploy проекта;
- redeploy после code changes;
- ротация `ZENROX_TELEGRAM_BOT_TOKEN` или `ZENROX_TELEGRAM_SECRET_TOKEN`;
- смена public URL сервиса;
- нужно подтвердить, что Telegram webhook снова доставляет сообщения в production.

## Safety Notes

- не коммитить secrets в Git и не вставлять их значения в markdown;
- `setWebhook` является mutating-операцией во внешней системе и должен указывать только на актуальный production URL;
- rollback к предыдущему deploy в Render не откатывает автоматически webhook URL, если он изменился.

## Diagnosis

1. Проверить, что web service `zenrox` и PostgreSQL доступны в Render dashboard.
2. Проверить, что в `Environment` заданы `DATABASE_URL`, `SECRET_KEY_BASE`, `ZENROX_TELEGRAM_BOT_TOKEN`.
3. Для live Telegram verify проверить также `ZENROX_TELEGRAM_SECRET_TOKEN`; `ZENROX_TELEGRAM_ALLOWED_CHAT_ID` опционален, но желателен для single-user режима.
4. Проверить health endpoint `https://zenrox.onrender.com/up`.

## Resolution

1. Push актуальный commit в Git remote, подключенный к Render.
2. Дождаться auto-deploy или запустить `Redeploy latest commit` из Render dashboard.
3. Убедиться, что deploy завершился успешно и `https://zenrox.onrender.com/up` отвечает `200`.
4. Выполнить `setWebhook` на `https://zenrox.onrender.com/telegram/webhook` с текущим `secret_token`.
5. Проверить `getWebhookInfo` и убедиться, что Telegram указывает на production URL.
6. Отправить боту сообщение `купить молоко` и дождаться user-visible подтверждения сохранения.
7. Отправить боту сообщение `задачи` и убедиться, что приходит user-visible список открытых задач.

## Rollback

1. В Render dashboard выполнить redeploy предыдущего успешного commit.
2. Проверить `https://zenrox.onrender.com/up`.
3. Если URL сервиса менялся, повторно выполнить `setWebhook` на актуальный URL.
4. Повторить минимальный Telegram smoke-check.

## Escalation

- если `GET /up` не отвечает после успешного deploy, смотреть Render application logs и database dashboard;
- если webhook установлен, но Telegram не доставляет сообщения, проверить `getWebhookInfo`, secret token и Render logs на `/telegram/webhook`;
- если проблема связана с миграцией schema, останавливать rollout до подтверждения состояния БД.
