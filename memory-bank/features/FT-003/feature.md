---
title: "FT-003: Telegram Mobile Capture Channel"
doc_kind: feature
doc_function: canonical
purpose: "Расширенный canonical feature-документ для первого phone-friendly delivery channel поверх существующего capture-path."
derived_from:
  - ../../domain/problem.md
  - ../../domain/frontend.md
  - ../../domain/architecture.md
  - ../../prd/PRD-001-first-capture-and-retrieval-loop.md
  - ../../use-cases/UC-006-single-task-text-capture.md
status: active
delivery_status: in_progress
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-003: Telegram Mobile Capture Channel

## What

### Problem

`FT-001` закрыл backend-only capture slice, но не дал пользователю реальный путь пользоваться им с телефона. На уровне продукта мобильная доступность уже нужна, однако без phone-friendly client surface backend endpoint сам по себе не превращается в "помощника в телефоне".

Для первого delivery channel нужен узкий и проверяемый slice: Telegram как основной bot-like интерфейс для single-user capture-flow. Этот slice должен прокинуть текстовое сообщение из приватного чата в уже существующий capture contract, вернуть пользователю короткий ответ и не порождать дубликаты задач при webhook retry или повторной доставке update.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Доступность capture-path с телефона | Capture-path существует только как backend API и не имеет real-world mobile entrypoint | Пользователь может отправить supported текстовую реплику в Telegram и получить user-visible результат через тот же канал | Deterministic request coverage на webhook contract и manual smoke-check на реальном телефоне |
| `MET-02` | Надежность Telegram delivery path | Webhook retry может приводить к повторной обработке и потенциальным дубликатам | Повторная доставка одного и того же Telegram update не создает вторую задачу и допускает повторную попытку доставить ответ пользователю | Automated retry scenario с фиксированным `update_id` |

### Scope

- `REQ-01` Система принимает Telegram webhook update с текстовым сообщением из приватного чата и прокидывает текст в общий capture-path.
- `REQ-02` После обработки capture-path система отправляет пользователю в Telegram короткий user-visible ответ, отражающий accepted, rejected или failed verdict backend-контракта.
- `REQ-03` Повторная обработка одного и того же Telegram update не должна создавать дублирующую задачу.
- `REQ-04` Интеграция читает bot token, optional secret token и optional allowed chat id через единый config owner-слой, а не напрямую из domain-кода.
- `REQ-05` Фича фиксирует минимальный verify path для Telegram-канала: deterministic automated coverage для webhook routing и retry behavior, плюс manual phone smoke-check как отдельный live-integration gap.

### Non-Scope

- `NS-01` Retrieval-ответы в Telegram, включая вопрос `какие у меня открытые дела?`.
- `NS-02` Group chats, multi-user routing, сложная авторизация и полноценный account model.
- `NS-03` Голосовые сообщения, изображения, файлы и другие нетекстовые Telegram payload types как supported input.
- `NS-04` Исходящие reminders, background jobs и push-like delivery beyond synchronous reply на входящее сообщение.
- `NS-05` Автоматическая регистрация webhook-а в Telegram, provisioning публичного URL и production deployment flow.

### Constraints / Assumptions

- `ASM-01` На текущем этапе проект single-user и early-stage; Telegram-канал может опираться на приватный чат как минимально достаточную surface.
- `ASM-02` Capture semantics остаются owner-ом `FT-001`; Telegram-канал не переопределяет admission rule и не вводит отдельную бизнес-логику разбора сообщений.
- `CON-01` Первый Telegram slice должен переиспользовать существующий capture backend contract вместо отдельного transport-specific parsing path.
- `CON-02` Telegram delivery path должен быть безопасен к webhook retry и повторной доставке update.
- `CON-03` Live phone verification зависит от bot token и публично доступного webhook URL, поэтому до появления non-local среды эта часть verify остается manual-only.
- `DEC-01` Первый production-like deployment path зафиксирован через Render Blueprint, а регистрация webhook-а остается manual release step и не блокирует локальную реализацию transport слоя.
- `RJ-01` Нетекстовый Telegram update не должен попадать в capture-path; вместо этого пользователь получает явный ответ, что сейчас поддерживаются только текстовые сообщения.

### Invariants

- `INV-01` Один Telegram `update_id` может привести максимум к одной новой задаче.
- `INV-02` User-visible Telegram reply должен отражать verdict общего capture-path, а не выдуманную transport-specific интерпретацию.
- `INV-03` Повторная доставка update может повторно пытаться доставить reply, но не может создавать вторую задачу.

## How

### Solution

Фича добавляет узкий interaction/platform слой для Telegram webhook поверх уже существующего `FT-001` capture service. Telegram update нормализуется до текстовой реплики, для retry-safe write-path получает стабильный `operation_id` на основе `update_id`, затем вызывает общий capture service и отправляет результат обратно через Telegram Bot API.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `telegram webhook entrypoint` | code / config | Нужен новый interaction-layer вход для phone-friendly сообщений |
| `capture write path` | code | Нужна retry-safe idempotency на уровне transport-derived `operation_id` |
| `platform config / telegram adapter` | code / ops | Нужен единый owner-слой для Telegram credentials и исходящей доставки reply |
| `automated / manual verify artifacts for telegram channel` | test / doc | Нужны deterministic webhook checks и явный manual smoke path |

### Flow

1. Telegram отправляет webhook update с текстовым сообщением из приватного чата.
2. Interaction-layer валидирует secret token, тип update и пригодность payload для capture-flow.
3. Для поддерживаемого текстового update interaction-layer вызывает общий capture-path с transport-derived `operation_id`.
4. Capture-path возвращает accepted, rejected или failed verdict без дублирования write-path при retry одного `update_id`.
5. Platform adapter отправляет в Telegram короткий текстовый reply с тем же verdict.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `telegram update -> capture text command` | Telegram webhook -> interaction -> capture-path | В capture-path попадает только текст из приватного чата |
| `CTR-02` | `telegram update_id -> stable operation_id` | interaction -> personal-memory write path | Один `update_id` должен давать idempotent write verdict |
| `CTR-03` | `capture verdict -> telegram text reply` | capture-path -> platform/telegram -> user | Reply обязан различать accepted, rejected и failed outcomes |
| `CTR-04` | `env/runtime config -> telegram integration` | platform config -> interaction/platform adapters | Token и optional guard settings читаются только через config owner |

### Failure Modes

- `FM-01` Один и тот же webhook update доставляется повторно, и система создает вторую задачу.
- `FM-02` Telegram-канал вводит собственные parsing rules, расходящиеся с backend capture contract.
- `FM-03` Нетекстовый update попадает в capture-path и приводит к ложному сохранению или confusing reply.
- `FM-04` Секрет или outbound delivery настроены неверно, а система маскирует это под успешную end-to-end обработку.
- `FM-05` Reply в Telegram не удается доставить после успешного сохранения, а повторная доставка webhook-а создает дубликат задачи.

## Verify

`Verify` задает canonical test case inventory для Telegram delivery channel: positive path через supported text update, negative coverage для non-text / unauthorized / duplicate-delivery сценариев и отдельный manual smoke-check для live phone path.

### Exit Criteria

- `EC-01` Supported текстовый Telegram update из приватного чата приводит к одному capture verdict и одному user-visible reply через Telegram.
- `EC-02` Повторная доставка одного и того же Telegram update не создает дублирующую задачу.
- `EC-03` Нетекстовый update не приводит к автосохранению и получает явный explanatory reply о текущем ограничении.
- `EC-04` Конфигурация Telegram-канала читается через один owner-слой и задокументирована в ops docs.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `ASM-02`, `CON-01`, `CTR-01`, `INV-02` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `CON-01`, `CTR-03`, `FM-02`, `FM-04` | `EC-01`, `SC-01`, `SC-03` | `CHK-01`, `CHK-03` | `EVID-01`, `EVID-03` |
| `REQ-03` | `CON-02`, `CTR-02`, `INV-01`, `INV-03`, `FM-01`, `FM-05` | `EC-02`, `SC-02` | `CHK-02` | `EVID-02` |
| `REQ-04` | `CTR-04`, `FM-04` | `EC-04`, `SC-03` | `CHK-03` | `EVID-03` |
| `REQ-05` | `CON-03`, `DEC-01`, `FM-04`, `RJ-01` | `EC-03`, `EC-04`, `SC-03`, `NEG-01`, `NEG-02` | `CHK-03`, `CHK-04` | `EVID-03`, `EVID-04` |

### Acceptance Scenarios

- `SC-01` Пользователь отправляет в Telegram supported текстовую реплику вроде `купить молоко`; система обрабатывает update через общий capture-path, сохраняет ровно одну `open`-задачу и отправляет reply `Задача сохранена.`.
- `SC-02` Telegram повторно доставляет тот же `update_id` после временного outbound failure; система не создает вторую задачу и при повторной обработке лишь повторяет попытку доставки reply.
- `SC-03` Telegram-канал запущен с config owner-слоем: secret/header check, bot token и optional allowed chat id читаются централизованно, а при нетекстовом сообщении пользователь получает явное ограничение текущего канала.

### Checks

Verify должен быть исполнимым.

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01` | Прогнать deterministic request-spec для `POST /telegram/webhook` с supported text update и stubbed Telegram client | Создается ровно одна `open`-задача, webhook отвечает success-status, outbound adapter получает текстовый reply с accepted verdict | `artifacts/ft-003/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-02` | Прогнать retry scenario с одним и тем же `update_id`, где первая outbound попытка проваливается, а вторая проходит | В БД остается одна задача, повторный webhook не создает дубликат, reply пытается отправиться повторно | `artifacts/ft-003/verify/chk-02/` |
| `CHK-03` | `EC-03`, `EC-04`, `SC-03`, `NEG-01`, `NEG-02` | Прогнать deterministic request-spec для нетекстового update и invalid secret с stubbed config/client | Нетекстовый update не создает задачу и получает explanatory reply; invalid secret не проходит обработку и не вызывает outbound delivery | `artifacts/ft-003/verify/chk-03/` |
| `CHK-04` | `EC-01`, `EC-04`, `SC-01`, `SC-03` | Выполнить manual smoke-check на реальном телефоне после настройки bot token и webhook URL | Сообщение из Telegram реально доходит до приложения и пользователь получает ответ в том же чате | `artifacts/ft-003/verify/chk-04/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-003/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-003/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-003/verify/chk-03/` |
| `CHK-04` | `EVID-04` | `artifacts/ft-003/verify/chk-04/` |

### Evidence

- `EVID-01` Артефакт successful Telegram capture через supported text update.
- `EVID-02` Артефакт retry-safe duplicate-delivery сценария.
- `EVID-03` Артефакт config guard и non-text handling сценариев.
- `EVID-04` Артефакт ручной проверки на реальном телефоне после настройки live integration.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Structured request-spec output для successful Telegram capture | verify-runner | `artifacts/ft-003/verify/chk-01/` | `CHK-01` |
| `EVID-02` | Structured request-spec output для webhook retry path | verify-runner | `artifacts/ft-003/verify/chk-02/` | `CHK-02` |
| `EVID-03` | Structured request-spec output для invalid secret и non-text handling | verify-runner | `artifacts/ft-003/verify/chk-03/` | `CHK-03` |
| `EVID-04` | Manual transcript, screenshot или checklist-result live Telegram smoke-check | human | `artifacts/ft-003/verify/chk-04/` | `CHK-04` |

### Negative Scenarios

- `NEG-01` Telegram присылает нетекстовый update; система не должна создавать задачу и должна явно сообщить, что сейчас поддерживаются только текстовые сообщения.
- `NEG-02` Webhook приходит без корректного secret token при включенной secret-check защите; система не должна обрабатывать update и не должна отправлять reply.
