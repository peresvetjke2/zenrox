# CHK-04 Manual Smoke Checklist

Дата выполнения: `YYYY-MM-DD`

Prerequisites:

- deployed Render URL доступен по `GET /up`
- заданы `ZENROX_TELEGRAM_BOT_TOKEN`
- при использовании secret guard задан `ZENROX_TELEGRAM_SECRET_TOKEN`
- при single-user allow-list задан `ZENROX_TELEGRAM_ALLOWED_CHAT_ID`

Procedure:

1. Выполнить `setWebhook` на `https://<render-service>.onrender.com/telegram/webhook`.
2. Отправить из разрешенного приватного чата supported текстовую реплику, например `купить молоко`.
3. Убедиться, что в Telegram пришел короткий reply с verdict capture-path.
4. При наличии доступа к приложению проверить, что новая задача создалась ровно один раз.

Expected result:

- webhook принимает live update
- пользователь получает reply в том же чате
- duplicate task не появляется

Evidence to attach:

- screenshot переписки или transcript
- ссылка/заметка на deployed URL
- при необходимости короткая заметка о manual approval на live smoke
