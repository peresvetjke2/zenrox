# CHK-04 Manual Smoke Evidence

Дата выполнения: `2026-05-05`

Environment:

- production URL: `https://zenrox.onrender.com`
- webhook URL: `https://zenrox.onrender.com/telegram/webhook`
- delivery surface: Telegram private chat

Procedure:

1. Выполнен `setWebhook` на production URL.
2. Отправлено сообщение `купить молоко` в live Telegram chat.
3. Получен reply capture-path в том же чате.
4. После этого live deploy использован и для retrieval smoke-check.

Observed result:

- webhook принимает live update на production Render service
- пользователь получает reply в том же чате
- production Telegram integration работает на постоянном public URL, а не на временном `dev+tunnel`

Evidence:

- пользователь подтвердил в этой сессии успешный production deploy и работающий Telegram flow
- `getWebhookInfo` указывал на `https://zenrox.onrender.com/telegram/webhook`
