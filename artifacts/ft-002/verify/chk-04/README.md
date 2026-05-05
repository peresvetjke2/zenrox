# CHK-04 Manual Smoke Evidence

Дата выполнения: `2026-05-05`

Environment:

- production URL: `https://zenrox.onrender.com`
- webhook URL: `https://zenrox.onrender.com/telegram/webhook`
- delivery surface: Telegram private chat

Procedure:

1. Выполнен `setWebhook` на production URL.
2. Отправлено сообщение `купить молоко` для проверки live capture-path.
3. Отправлено сообщение `задачи` для проверки live retrieval-path.

Observed result:

- production deploy доступен по публичному Render URL
- Telegram webhook успешно зарегистрирован и `getWebhookInfo` указывает на production URL
- live capture работает
- live retrieval работает

Evidence:

- пользователь в рамках этой сессии подтвердил, что после production deploy и webhook setup Telegram flow "работает как часы"
- `CHK-04` для `FT-002` считается подтвержденным ручным smoke-check в production
