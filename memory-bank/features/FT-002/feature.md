---
title: "FT-002: Open Tasks Retrieval Query"
doc_kind: feature
doc_function: canonical
purpose: "Расширенный canonical feature-документ для первого retrieval slice: ответ на вопрос о всех открытых задачах без потери задач без срока и без записи новых данных."
derived_from:
  - ../../domain/problem.md
  - ../../domain/architecture.md
  - ../../prd/PRD-001-first-capture-and-retrieval-loop.md
  - ../../use-cases/UC-007-open-tasks-retrieval.md
status: active
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-002: Open Tasks Retrieval Query

## What

### Problem

`FT-001` и `FT-003` дают пользователю способ сохранить задачу и сделать это с телефона, но не закрывают вторую половину первого полезного цикла из `PRD-001`: позже поднять полный список открытых дел. Пока retrieval-path отсутствует, накопленная task memory не превращается в практический обзор личного бэклога, а пользователь не может надежно получить обзор по запросу `задачи` без ручного перебора истории.

Для первого retrieval slice нужен узкий и проверяемый контракт: система распознает точную команду `задачи` как retrieval-intent, читает все задачи со статусом `open`, не теряет записи без срока выполнения, исключает `done` и возвращает user-visible ответ без побочных записей в task storage.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Полнота обзора открытых дел | Сейчас пользователь не может получить system-backed список всех открытых задач одним вопросом | В supported retrieval-сценарии пользователь получает полный список `open`-задач, включая задачи без срока выполнения | Deterministic checks на смешанном наборе `open` / `done` задач |
| `MET-02` | Безопасность retrieval-маршрутизации | Retrieval-вопрос может быть ошибочно обработан как capture-ввод или дать guessed answer | Supported запрос `задачи` не создает новую задачу и не меняет существующие записи | Request/service coverage на routing и read-only behavior |
| `MET-03` | Практическая пригодность первого retrieval с телефона | После `FT-003` Telegram-канал умеет capture, но не retrieval | Пользователь может отправить запрос `задачи` через текущий Telegram-канал и получить user-visible список открытых дел | Deterministic transport-level check и manual Telegram smoke-check при реализации |

### Scope

- `REQ-01` Система распознает точный supported input `задачи` как retrieval-intent первого MVP и не маршрутизирует его в capture-path.
- `REQ-02` Retrieval-path возвращает все задачи со статусом `open` и исключает задачи со статусом `done`.
- `REQ-03` Задачи без срока выполнения, проекта или других дополнительных атрибутов не теряются и включаются в ответ на тех же правах, что и остальные `open`-задачи.
- `REQ-04` Ответ пользователю является user-visible и детерминированным: при одном и том же наборе задач список отдается в одном и том же стабильном порядке `oldest-first`, используя возрастающий `task.id` как MVP-прокси порядка создания.
- `REQ-05` Supported retrieval-запрос не создает новых задач, не обновляет существующие и не меняет task statuses.
- `REQ-06` Первый retrieval slice доступен через текущую Telegram conversational surface проекта, пригодную для phone-friendly usage.
- `REQ-07` Фича задает минимальный verify-path: automated coverage для retrieval filtering, empty-state, routing и read-only invariants, плюс отдельный manual Telegram smoke-check на live surface.
- `REQ-08` Retrieval-path возвращает детерминированный user-visible текстовый verdict: для non-empty case — заголовок `Открытые задачи:` и далее по одной задаче на строку в формате `- <task.body>` в stable order; для empty-state — `Открытых задач нет.`; для read failure — `Не удалось получить список открытых задач.` без частичного списка.

### Non-Scope

- `NS-01` Date-based или context-based retrieval-вопросы вроде `что у меня на сегодня?` или `что у меня по работе?`.
- `NS-02` Retrieval заметок, фактов, проектов, подзадач и связанных сущностей beyond plain task list.
- `NS-03` Изменение статуса задач, включая пользовательские команды перевода задачи в `done`.
- `NS-04` Семантический поиск, ranking по релевантности, grouped summaries и любые сложные вычисления поверх найденных задач.
- `NS-05` Multi-user behavior, shared backlogs, permissions-aware filtering и account model.
- `NS-06` Автоматическая нормализация любого свободного retrieval-вопроса; первый slice может поддерживать только узкий deterministic intent contract.

### Constraints / Assumptions

- `ASM-01` На текущем этапе task storage уже поддерживает как минимум статусы `open` и `done`, а `Task` остается source of truth для первого retrieval slice.
- `ASM-02` После `FT-003` у проекта уже есть Telegram как phone-friendly conversational surface, и первый retrieval slice должен переиспользовать ее, а не вводить параллельный mobile-only канал.
- `CON-01` Первый retrieval slice intentionally narrow: он покрывает только команду `задачи` для полного списка открытых дел и не расширяется до date/context filtering.
- `CON-02` Retrieval-path обязан быть read-only относительно task storage.
- `CON-03` Product-инвариант `open = not done` должен соблюдаться в user-visible retrieval без скрытых исключений по дате, проекту или дополнительным атрибутам.
- `CON-04` Для первого MVP допустимо узкое deterministic intent recognition вместо общего natural-language router-а; supported input ограничен точной командой `задачи` без дополнительной нормализации текста.
- `CON-05` Порядок выдачи должен быть стабильным и воспроизводимым; для первого MVP это означает `oldest-first` по возрастающему `task.id`, а не случайный порядок БД.
- `CON-06` Live mobile acceptance для Telegram зависит от bot token, webhook URL и внешней delivery surface, поэтому эта часть verify остается manual-only до наличия non-local среды.
- `DEC-01` Точная форма backend verify surface для deterministic checks может быть выбрана downstream, если она не переопределяет user-facing contract Telegram retrieval.
- `RJ-01` Первый retrieval slice не должен расширяться до parser-like распознавания retrieval-вопросов beyond exact command `задачи`; любые такие расширения оформляются отдельным downstream change.

### Invariants

- `INV-01` Retrieval вопрос не создает, не обновляет и не закрывает задачи.
- `INV-02` Любая задача со статусом `open` попадает в supported retrieval-answer независимо от наличия срока выполнения.
- `INV-03` Любая задача со статусом `done` исключается из supported retrieval-answer.
- `INV-04` Один и тот же набор релевантных задач должен давать один и тот же пользовательский порядок выдачи.

## How

### Solution

Фича добавляет узкий retrieval-path поверх существующего task storage и текущей Telegram surface. Supported запрос `задачи` проходит через deterministic intent recognition, затем retrieval service читает `Task` как owner-слой, отбирает только `open`-задачи, сортирует их `oldest-first` по возрастающему `task.id` и возвращает user-visible ответ без записи в capture write-path. Slice intentionally не вводит отдельный parser для retrieval-like вопросов beyond exact command.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `conversational routing for text messages` | code | Нужен explicit route для retrieval-intent, чтобы supported query не уходил в capture-path |
| `task retrieval query/service` | code | Нужен owner-safe read-path, который отбирает только `open` и задает порядок `oldest-first` |
| `user-visible retrieval response formatter` | code | Нужен минимальный reply contract для non-empty и empty-state ответов |
| `telegram interaction surface` | code / integration | Existing Telegram channel должен уметь возвращать retrieval-answer, а не только capture verdict |
| `automated / manual verify artifacts for retrieval channel` | test / doc | Нужны deterministic checks на filtering, routing, empty-state и read-only behavior |

### Flow

1. Пользователь отправляет supported запрос `задачи` через текущую Telegram surface.
2. Interaction-layer распознает retrieval-intent первого MVP и не передает запрос в capture-path.
3. Retrieval service читает task storage, отбирает все записи со статусом `open` и исключает `done`.
4. Response formatter строит user-visible список в порядке `oldest-first` или явный empty-state ответ.
5. Платформа возвращает ответ пользователю без изменения task storage.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `exact tasks command -> retrieval intent` | interaction -> retrieval path | Поддерживается только точный запрос `задачи`; он маршрутизируется в retrieval, а не в capture |
| `CTR-02` | `task storage -> stable list of open tasks` | personal-memory -> retrieval path | В выборку входят все `open`-задачи, не входят `done`, порядок выдачи — по возрастанию `task.id` |
| `CTR-03` | `open tasks collection -> user-visible textual answer` | retrieval path -> interaction/user | Для non-empty case ответ начинается со строки `Открытые задачи:` и далее перечисляет задачи по одной на строку в формате `- <task.body>` в stable order; для empty-state возвращается `Открытых задач нет.` |
| `CTR-04` | `retrieval request -> no storage mutation` | interaction/retrieval -> personal-memory | Read-path не создает и не обновляет task records |
| `CTR-05` | `retrieval read failure -> explicit failed response` | retrieval path -> interaction/user | Если owner-layer чтение не завершилось успешно, пользователь получает `Не удалось получить список открытых задач.` без частичного списка и без fallback к capture-path |

### Failure Modes

- `FM-01` Supported retrieval-вопрос ошибочно маршрутизируется в capture-path и создает ложную новую задачу.
- `FM-02` Ответ возвращает не все `open`-задачи, потому что часть записей без срока или без дополнительных атрибутов выпадает из выборки.
- `FM-03` В ответ попадают `done`-задачи, и пользователь получает искаженный обзор текущего бэклога.
- `FM-04` Порядок выдачи зависит от случайного порядка БД или transport-specific деталей, из-за чего одинаковый набор задач выглядит по-разному между запросами.
- `FM-05` Empty backlog воспринимается как ошибка интеграции или молчаливый no-op вместо явного ответа.
- `FM-06` Read-only retrieval-path вызывает побочную запись, обновление change state или другой storage mutation.
- `FM-07` Сбой чтения task storage приводит к частичному списку, capture fallback или неявной transport error вместо явного retrieval failure verdict.

## Verify

`Verify` задает canonical test case inventory для первого retrieval slice: positive path для полного списка открытых задач, negative coverage для `done` leakage, read-only invariants и failure-path чтения, плюс explicit empty-state behavior.

### Exit Criteria

- `EC-01` Supported запрос `задачи` возвращает полный список текущих `open`-задач и исключает `done`.
- `EC-02` Задачи без срока выполнения не теряются и попадают в ответ на тех же правах, что и остальные `open`-задачи.
- `EC-03` При отсутствии открытых задач пользователь получает явный empty-state ответ, а не ошибку и не пустую молчанку.
- `EC-04` Supported retrieval-запрос не приводит к записи новой задачи, изменению статуса или другой storage mutation.
- `EC-05` Current Telegram conversational surface возвращает retrieval-answer пользователю в том же канале.
- `EC-06` Live Telegram flow после настройки bot token и webhook URL подтверждает, что retrieval-answer реально доходит до пользователя с телефона.
- `EC-07` При неуспешном чтении task storage пользователь получает явный failed verdict без частичного списка и без storage mutation.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `CON-01`, `CON-04`, `CTR-01`, `RJ-01`, `FM-01` | `EC-01`, `SC-01`, `SC-04` | `CHK-01`, `CHK-03` | `EVID-01`, `EVID-03` |
| `REQ-02` | `ASM-01`, `CON-03`, `CTR-02`, `INV-02`, `INV-03`, `FM-02`, `FM-03` | `EC-01`, `SC-01`, `NEG-01` | `CHK-01` | `EVID-01` |
| `REQ-03` | `CON-03`, `CTR-02`, `INV-02`, `FM-02` | `EC-02`, `SC-02` | `CHK-01` | `EVID-01` |
| `REQ-04` | `CON-05`, `CTR-03`, `INV-04`, `FM-04`, `FM-05` | `EC-03`, `SC-01`, `SC-03` | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` |
| `REQ-05` | `CON-02`, `CTR-04`, `INV-01`, `FM-06` | `EC-04`, `SC-01`, `SC-03`, `NEG-02` | `CHK-01`, `CHK-02`, `CHK-03` | `EVID-01`, `EVID-02`, `EVID-03` |
| `REQ-06` | `ASM-02`, `DEC-01`, `CTR-03`, `FM-01` | `EC-05`, `EC-06`, `SC-04`, `SC-05` | `CHK-03`, `CHK-04` | `EVID-03`, `EVID-04` |
| `REQ-07` | `CON-06`, `DEC-01`, `CTR-05`, `FM-05`, `FM-06`, `FM-07` | `EC-03`, `EC-04`, `EC-06`, `EC-07`, `SC-03`, `SC-04`, `SC-05`, `SC-06`, `NEG-02`, `NEG-03` | `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05` | `EVID-02`, `EVID-03`, `EVID-04`, `EVID-05` |
| `REQ-08` | `CTR-03`, `CTR-05`, `FM-05`, `FM-07` | `EC-03`, `EC-07`, `SC-01`, `SC-03`, `SC-06`, `NEG-03` | `CHK-01`, `CHK-02`, `CHK-05` | `EVID-01`, `EVID-02`, `EVID-05` |

### Acceptance Scenarios

- `SC-01` В системе есть смешанный набор задач: `купить молоко` (`open`), `позвонить маме` (`done`), `записаться к врачу` (`open` без срока). Пользователь отправляет канонический запрос `задачи` и получает user-visible список из двух `open`-задач без `done`-записи, начиная с заголовка `Открытые задачи:` и далее строками `- купить молоко`, `- записаться к врачу`.
- `SC-02` Все открытые задачи не имеют срока выполнения, но пользователь все равно получает их полный список без скрытой date-based фильтрации и в том же stable text format `Открытые задачи:` + `- <task.body>`.
- `SC-03` В системе нет открытых задач; запрос `задачи` возвращает явный empty-state ответ `Открытых задач нет.` и не меняет сохраненные записи.
- `SC-04` Пользователь отправляет запрос `задачи` через текущий Telegram-канал и получает ответ в том же канале без создания новой задачи.
- `SC-05` После настройки live Telegram integration пользователь отправляет запрос `задачи` с телефона и получает тот же retrieval-answer в реальном чате.
- `SC-06` Во время supported retrieval owner-layer чтение task storage завершается неуспешно; пользователь получает явный failed verdict `Не удалось получить список открытых задач.` без частичного списка и без изменения сохраненных записей.

### Checks

Verify должен быть исполнимым.

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-02`, `SC-01`, `SC-02`, `NEG-01` | Прогнать deterministic request/service spec на наборе задач со статусами `open` и `done`, включая записи без срока выполнения | Ответ содержит все и только `open`-задачи, не теряет задачи без срока и выдает точный текст `Открытые задачи:` с последующими строками `- <task.body>` в стабильном порядке | `artifacts/ft-002/verify/chk-01/` |
| `CHK-02` | `EC-03`, `EC-04`, `SC-03`, `NEG-02` | Прогнать deterministic empty-backlog сценарий и проверить task count / statuses до и после запроса | Система возвращает явный empty-state ответ, а task storage остается без изменений | `artifacts/ft-002/verify/chk-02/` |
| `CHK-03` | `EC-04`, `EC-05`, `SC-04` | Прогнать transport-level deterministic check через текущую Telegram surface с stubbed delivery client | Запрос `задачи` не создает задачу и возвращает user-visible ответ в том же канале | `artifacts/ft-002/verify/chk-03/` |
| `CHK-04` | `EC-06`, `SC-05` | Выполнить manual Telegram smoke-check на реальном телефоне после настройки bot token и webhook URL: заранее подготовить хотя бы одну `open`-задачу, отправить `задачи` из разрешенного приватного чата и сохранить transcript/screenshot запроса и ответа | Запрос `задачи` реально доходит до приложения, user-visible retrieval-answer возвращается в тот же Telegram-чат и его текст соответствует canonical verdict contract | `artifacts/ft-002/verify/chk-04/` |
| `CHK-05` | `EC-07`, `SC-06`, `NEG-03` | Прогнать deterministic retrieval read failure через injected failure/stub owner-layer и проверить verdict и storage state | Пользователь получает `Не удалось получить список открытых задач.`, не получает частичный список и task storage остается без изменений | `artifacts/ft-002/verify/chk-05/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-002/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-002/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-002/verify/chk-03/` |
| `CHK-04` | `EVID-04` | `artifacts/ft-002/verify/chk-04/` |
| `CHK-05` | `EVID-05` | `artifacts/ft-002/verify/chk-05/` |

### Evidence

- `EVID-01` Артефакт mixed-status retrieval, подтверждающий inclusion всех `open` и exclusion всех `done`.
- `EVID-02` Артефакт empty-state retrieval, подтверждающий явный ответ и отсутствие storage mutation.
- `EVID-03` Артефакт retrieval delivery через текущий Telegram-канал.
- `EVID-04` Артефакт ручной проверки команды `задачи` на реальном телефоне через live Telegram integration.
- `EVID-05` Артефакт retrieval read failure, подтверждающий явный failed verdict и отсутствие частичного списка.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Structured verify output для mixed-status retrieval | verify-runner | `artifacts/ft-002/verify/chk-01/` | `CHK-01` |
| `EVID-02` | Structured verify output для empty-state retrieval | verify-runner | `artifacts/ft-002/verify/chk-02/` | `CHK-02` |
| `EVID-03` | Structured request-spec или equivalent output для transport-level retrieval delivery | verify-runner | `artifacts/ft-002/verify/chk-03/` | `CHK-03` |
| `EVID-04` | Manual transcript, screenshot или checklist-result live Telegram retrieval smoke-check с зафиксированными запросом `задачи` и полученным reply | human | `artifacts/ft-002/verify/chk-04/` | `CHK-04` |
| `EVID-05` | Structured verify output для retrieval read failure | verify-runner | `artifacts/ft-002/verify/chk-05/` | `CHK-05` |

### Negative Scenarios

- `NEG-01` В storage есть `done`-задачи; они не должны появляться в ответе на supported запрос `задачи`.
- `NEG-02` Empty backlog не должен приводить к созданию placeholder-задачи, скрытому изменению статусов или молчаливому пустому ответу.
- `NEG-03` Failure чтения task storage не должен приводить к partial retrieval-answer, fallback в capture-path или скрытой mutation.
