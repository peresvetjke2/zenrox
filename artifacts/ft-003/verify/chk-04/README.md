# CHK-04 Manual Smoke Checklist

Дата выполнения: `2026-05-05`

Prerequisites:

- доступен public webhook URL через stable non-local deploy или временный `dev+tunnel`
- заданы `ZENROX_TELEGRAM_BOT_TOKEN`
- при использовании secret guard задан `ZENROX_TELEGRAM_SECRET_TOKEN`
- при single-user allow-list задан `ZENROX_TELEGRAM_ALLOWED_CHAT_ID`

Procedure:

1. Выполнить `setWebhook` на выбранный public URL вида `https://<host>/telegram/webhook`.
2. Отправить из разрешенного приватного чата supported текстовую реплику, например `купить молоко`.
3. Убедиться, что в Telegram пришел короткий reply с verdict capture-path.
4. При наличии доступа к приложению проверить, что новая задача создалась ровно один раз.

Expected result:

- webhook принимает live update
- пользователь получает reply в том же чате
- duplicate task не появляется

Evidence:

- smoke-check выполнен через временный `dev+tunnel` public URL
- пользователь подтвердил, что сообщение в `@zenrox_helper_bot` отработало и поведение выглядит корректным
- live-check был выполнен в рамках этой сессии с явным запросом пользователя на dev live-test
