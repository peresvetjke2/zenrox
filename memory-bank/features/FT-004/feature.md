---
title: "FT-004: Conversational Intent Routing For Core Task Actions"
doc_kind: feature
doc_function: canonical
purpose: "Расширенный canonical feature-документ для первого intent-routing слоя, который различает базовые task-intents, безопасно переиспользует существующие capability и не маскирует неподдержанные или неоднозначные запросы."
derived_from:
  - ../../domain/problem.md
  - ../../domain/frontend.md
  - ../../domain/architecture.md
  - ../../prd/PRD-002-conversational-routing-for-core-assistant-actions.md
  - ../../use-cases/UC-004-task-status-lifecycle.md
  - ../../use-cases/UC-006-single-task-text-capture.md
  - ../../use-cases/UC-007-open-tasks-retrieval.md
status: active
delivery_status: planned
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-004: Conversational Intent Routing For Core Task Actions

## What

### Problem

`PRD-002` фиксирует следующий UX-разрыв после `PRD-001`: базовые возможности работы с задачами уже существуют или планируются, но разговорная точка входа по-прежнему хрупка и зависит от специальных формулировок, а при расширении scope возникает риск ложной интерпретации действий с изменением состояния. Без отдельного routing-контракта проекту будет трудно безопасно наращивать поведение на естественном языке: retrieval может продолжать зависеть от точной команды, lifecycle-intents могут случайно утечь в capture-path, а неоднозначные запросы начнут приводить к действию по догадке вместо уточнения.

`FT-004` нужен как узкий и проверяемый базовый слой. Эта фича не добавляет сама по себе общий "умный ассистент" и не реализует весь lifecycle задач. Ее задача — зафиксировать первую явную taxonomy поддерживаемых task-intents, контракт routing-вердиктов и правила безопасной передачи управления к существующим или downstream-возможностям так, чтобы один и тот же разговорный канал мог различать базовые пользовательские намерения, честно отказывать в unsupported случаях и не выполнять побочные изменения состояния при неуверенности.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Явность первого routing-слоя | Сейчас разрешение намерения либо завязано на специальные команды, либо остается незафиксированным между отдельными срезами возможностей | Каждый supported input получает один явный `intent_label` из ограниченной taxonomy и один однозначный `resolution_status`; ambiguous и unsupported inputs не протекают в capture по умолчанию | Детерминированные проверки маршрутизации намерений на фиксированном корпусе реплик |
| `MET-02` | Безопасность для intent-ов с изменением состояния | При расширении входа на естественном языке растет риск ошибочного выполнения capture или lifecycle-действия | Routing-слой не выбирает действие по догадке при ambiguity и не маршрутизирует lifecycle-intents в capture/retrieval по умолчанию | Негативное покрытие для ambiguous, mixed-intent и пока не исполняемых lifecycle-входов |
| `MET-03` | Переиспользуемость существующих возможностей | `FT-001` и `FT-002` уже определяют capture/retrieval contracts, но у них нет общего разговорного маршрутизатора | Routing verdict для capture и retrieval переиспользует их downstream contracts без изменения пользовательской семантики доверия | Проверка на уровне контракта для результата routing-передачи |

### Scope

- `REQ-01` Фича вводит ограниченную и явную taxonomy поддерживаемых task-intents первого routing layer: `capture_task`, `list_open_tasks`, `mark_task_done`, `reopen_task`, `delete_task`.
- `REQ-02` Routing-слой принимает одну текстовую реплику из текущего разговорного канала и выдает ровно один routing verdict с машиночитаемыми `intent_label` и `resolution_status` из набора `handoff`, `clarification_needed`, `unsupported`, `pending_executor`; если безопасно выбрать один supported intent нельзя, `intent_label` должен быть `none`.
- `REQ-03` Для capture- и retrieval-intents routing слой переиспользует уже существующие downstream capability contracts `FT-001` и `FT-002` и не расширяет их product semantics.
- `REQ-04` Lifecycle-intents (`mark_task_done`, `reopen_task`, `delete_task`) распознаются как отдельный класс и не должны по умолчанию проваливаться в capture-path, retrieval-path или silent no-op, даже если их полное выполнение остается downstream scope.
- `REQ-05` Если одна реплика разумно соответствует нескольким intents, нескольким возможным task targets или mixed-intent сценарию, routing-слой не выполняет действие с изменением состояния и возвращает clarification verdict с указанием, что именно нужно уточнить.
- `REQ-06` Unsupported или выходящий за scope запрос получает явный non-success verdict, который не создает впечатления, что assistant что-то сохранил, завершил, вернул в работу или удалил.
- `REQ-07` Для side-effecting lifecycle-intents handoff допустим только когда routing verdict содержит ровно один безопасно resolved target reference по правилам `PRD-002`; иначе verdict обязан оставаться `clarification_needed`.
- `REQ-08` Фича задает routing outcome contract, достаточный для последующих `FT-005` и `FT-006`: downstream-обработчик может опереться на `intent_label`, `resolution_status`, исходную реплику и optional structured target reference, не переопределяя базовую taxonomy.

### Non-Scope

- `NS-01` Реализация самого retrieval-ответа с локальными номерами задач и UX локальных ссылок по контексту; это downstream scope `FT-005`.
- `NS-02` Реальное изменение статуса задачи или удаление записи; это downstream scope `FT-006`.
- `NS-03` Multi-intent decomposition одной реплики на несколько исполняемых действий с частичным применением.
- `NS-04` Семантический поиск общего назначения, извлечение знаний, note/fact intents и любые действия с personal-memory вне базовых task-actions `PRD-002`.
- `NS-05` Изменение admission rule для single-task capture, точных текстов verdict в `FT-001` или retrieval-result contract `FT-002`.
- `NS-06` Новый клиент, расширенный UI, экран просмотра списка или продуктовая логика, завязанная на конкретный транспорт.

### Constraints / Assumptions

- `ASM-01` На текущем этапе primary conversational surface остается text-first и mobile-friendly; routing должен работать в том же канале без отдельного режима ввода.
- `ASM-02` `FT-001` и `FT-002` остаются canonical owner-ами user-visible contracts для capture и retrieval; routing слой лишь выбирает downstream capability.
- `ASM-03` `UC-004` пока находится в статусе `draft`; `FT-004` может опираться на него как на upstream-сценарий намерения, но не должен считать детали исполнения lifecycle полностью стабилизированными.
- `CON-01` Первый routing-слой намеренно узкий и поддерживает только single-intent сценарии; он покрывает только taxonomy из `REQ-01` и не расширяется до открытого поведения ассистента.
- `CON-02` Безопасность важнее полноты распознавания: ambiguous или mixed-intent input должен приводить к clarification или явному unsupported verdict, а не к действию по догадке.
- `CON-03` Routing слой не меняет канонические downstream contracts `FT-001` и `FT-002`; если для реализации capture/retrieval требуется semantic expansion их собственных правил, это оформляется отдельным feature change в соответствующем owner-слое.
- `CON-04` Для lifecycle-intent с изменением состояния routing verdict может перейти в `handoff` или `pending_executor` только если target task определена ровно одна: либо по точному совпадению текста ровно с одной существующей задачей, либо по context-local reference, когда такой owner ссылок будет введен downstream в `FT-005`.
- `CON-05` Для destructive intent `delete_task` любая неуверенность в intent или разрешении целевой задачи обязана приводить к `clarification_needed`, а не к удалению по догадке.
- `CON-06` Для первого шага lifecycle-routing допустимо вернуть supported intent verdict со статусом `pending_executor` без немедленного изменения состояния, если downstream-исполнитель еще не реализован; но такой verdict не должен маскироваться под успешное выполнение действия.
- `CON-07` Один input message должен давать максимум один routing verdict.
- `CON-08` `intent_label = none` допустим только для действительно unsupported, mixed-intent или слишком неоднозначных запросов, где безопасно выбрать один supported intent из `REQ-01` нельзя.
- `DEC-01` Техника intent classification не выбрана и не является частью feature contract, пока она выдерживает taxonomy, safety rules и deterministic verify этой фичи.
- `RJ-01` Реплика, выходящая за узкий scope task-action или требующая выполнения нескольких действий сразу, должна получать явный non-success verdict без побочных изменений состояния и с кратким указанием, какое упрощение или уточнение нужно.

### Invariants

- `INV-01` Routing не может приводить к побочному изменению состояния без downstream capability, которая явно выбрана текущим verdict-ом и получает `handoff`.
- `INV-02` Lifecycle-intent не может быть silently reinterpreted как capture-task только потому, что реплика содержит глагол действия и существительное.
- `INV-03` Capture и retrieval после routing сохраняют свои исходные trust contracts: success-like ответ возможен только после успешного завершения соответствующего downstream path.
- `INV-04` Один и тот же input при одинаковом conversational context должен давать один и тот же routing verdict.
- `INV-05` Side-effecting lifecycle command без единственного безопасно resolved target не может получить статус `handoff`.

## How

### Solution

Фича добавляет узкий слой маршрутизации намерений между входной текстовой репликой и downstream-возможностью работы с задачами. Слой классифицирует сообщение в одну из ограниченных intent-категорий, затем выставляет отдельный `resolution_status` и возвращает нормализованный verdict object. После этого он либо передает управление существующему capture/retrieval-обработчику, либо останавливается на `clarification_needed`, `unsupported` или `pending_executor`. Главный trade-off — сознательно узкая полнота распознавания ради предсказуемости и защиты от ложных побочных действий.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `assistant-orchestration / routing entrypoint` | code | Нужен owner-слой для первой intent taxonomy и verdict contract |
| `capture / retrieval integration boundary` | code | Нужна явная передача управления в существующие возможности без изменения их contract |
| `conversation context state for routing` | code / data | Нужен минимальный контекстный вход для детерминированного verdict при follow-up или ambiguity |
| `target reference normalization boundary` | code / data | Нужен единый contract для точного совпадения текста и будущих context-local references без смешения с логикой исполнения |
| `unsupported / clarification response layer` | code / doc | Нужны пользовательские безопасные verdict вместо молчаливого fallback |
| `verify artifacts for routing taxonomy` | test / doc | Нужны детерминированные routing-проверки и negative coverage по safety-сценариям |

### Flow

1. Пользователь отправляет одну текстовую реплику в текущий conversational channel.
2. Routing layer анализирует текст и доступный минимальный conversational context.
3. Система выбирает ровно один `intent_label` из taxonomy `REQ-01`, затем вычисляет `resolution_status`.
4. Если `resolution_status = handoff` и `intent_label` равен `capture_task` или `list_open_tasks`, сообщение передается соответствующему downstream-владельцу возможности без изменения его пользовательского контракта.
5. Если `intent_label` относится к lifecycle и исполнитель еще не готов, verdict получает статус `pending_executor`; если intent или target неоднозначны, verdict получает `clarification_needed`; если запрос вне scope, verdict получает `unsupported`.
6. Любой verdict, отличный от `handoff`, возвращает явный пользовательский non-success результат без побочного изменения task state.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `text message + minimal conversational context -> routing verdict{intent_label, resolution_status, optional target_reference}` | interaction -> routing layer | Verdict обязан содержать ровно один intent label из taxonomy `REQ-01` либо `none`, и ровно один `resolution_status` |
| `CTR-02` | `routing verdict(capture_task) -> FT-001 capture request` | routing layer -> capture capability | Routing не расширяет admission semantics single-task capture |
| `CTR-03` | `routing verdict(list_open_tasks) -> FT-002 retrieval request` | routing layer -> retrieval capability | Routing может распознать paraphrase, но retrieval result contract остается owner-ом `FT-002` |
| `CTR-04` | `routing verdict(lifecycle-intent) -> lifecycle executor or non-success response` | routing layer -> downstream lifecycle capability / user-facing response | `handoff` допустим только при единственном resolved target; до `FT-006` статус `pending_executor` не должен считаться успешным изменением task state |
| `CTR-05` | `clarification_needed / unsupported -> explicit non-success verdict` | routing layer -> user-facing response | Verdict должен объяснять, что именно неясно или вне scope, и подтверждать отсутствие выполненного действия |
| `CTR-06` | `routing verdict -> audit / verify surface` | routing layer -> logs / tests | Verify должен уметь доказать выбранный intent label и отсутствие unintended handoff |

### Failure Modes

- `FM-01` Retrieval-парафраза ошибочно маршрутизируется в capture-path и создает новую задачу вместо чтения списка.
- `FM-02` Lifecycle-команда вроде `закрой купить молоко` интерпретируется как новая задача, а не как lifecycle-intent или clarification.
- `FM-03` Mixed-intent реплика вроде `покажи задачи и закрой первую` приводит к частичному побочному изменению вместо безопасного уточнения.
- `FM-04` Routing verdict для capture или retrieval меняет user-facing success/failure semantics, already owned downstream feature.
- `FM-05` Unsupported запрос получает confusing ответ, из которого непонятно, было ли что-то сохранено или изменено.
- `FM-06` Один и тот же input при одинаковом context иногда дает разные routing verdict-ы.
- `FM-07` Lifecycle-intent без готового executor выглядит для пользователя как успешное завершение, хотя task state не менялся.
- `FM-08` `delete_task` при неуверенности в разрешении целевой задачи получает передачу управления по догадке вместо уточнения.

## Verify

`Verify` задает canonical test case inventory для routing-слоя: happy path для capture/retrieval-маршрутизации, отдельное покрытие для распознавания lifecycle-intent без непреднамеренного изменения состояния и строгое negative coverage для ambiguity, mixed intent и unsupported запросов.

### Exit Criteria

- `EC-01` Routing-слой детерминированно различает capture-intent и retrieval-intent по ограниченному supported корпусу реплик и передает их в корректную downstream-возможность.
- `EC-02` Lifecycle-intents распознаются как отдельный routing class и не проваливаются по умолчанию в capture или retrieval.
- `EC-03` Ambiguous, mixed-intent и unsupported запросы не приводят к побочным изменениям состояния и получают явный clarification или unsupported verdict.
- `EC-04` Routing layer не меняет canonical user-visible success semantics downstream features `FT-001` и `FT-002`.
- `EC-05` До появления `FT-006` lifecycle-intent не может выглядеть как успешно выполненное изменение task state.
- `EC-06` Lifecycle verdict с изменением состояния получает `handoff` только при единственном безопасном разрешении целевой задачи; `delete_task` при любой неуверенности остается на clarification.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `CON-01`, `CON-02`, `CTR-01`, `FM-01`, `FM-02`, `FM-03` | `EC-01`, `EC-02`, `EC-03`, `SC-01`, `SC-02`, `SC-03` | `CHK-01`, `CHK-02`, `CHK-03` | `EVID-01`, `EVID-02`, `EVID-03` |
| `REQ-02` | `CON-07`, `CON-08`, `CTR-01`, `CTR-06`, `INV-04`, `FM-06` | `EC-01`, `EC-03`, `SC-01`, `SC-02`, `SC-04`, `SC-05` | `CHK-01`, `CHK-02`, `CHK-03` | `EVID-01`, `EVID-02`, `EVID-03` |
| `REQ-03` | `ASM-02`, `CON-03`, `CTR-02`, `CTR-03`, `INV-03`, `FM-04` | `EC-01`, `EC-04`, `SC-01`, `SC-02` | `CHK-01`, `CHK-04` | `EVID-01`, `EVID-04` |
| `REQ-04` | `ASM-03`, `CON-06`, `CTR-04`, `INV-02`, `FM-02`, `FM-07` | `EC-02`, `EC-05`, `SC-03` | `CHK-02`, `CHK-05` | `EVID-02`, `EVID-05` |
| `REQ-05` | `CON-02`, `RJ-01`, `CTR-05`, `FM-03` | `EC-03`, `SC-04`, `NEG-01`, `NEG-02` | `CHK-03` | `EVID-03` |
| `REQ-06` | `CON-02`, `RJ-01`, `CTR-05`, `INV-01`, `FM-05` | `EC-03`, `SC-05`, `NEG-03` | `CHK-03` | `EVID-03` |
| `REQ-07` | `CON-04`, `CON-05`, `CTR-01`, `CTR-04`, `INV-05`, `FM-08` | `EC-06`, `SC-03`, `SC-06`, `NEG-04` | `CHK-02`, `CHK-05`, `CHK-06` | `EVID-02`, `EVID-05`, `EVID-06` |
| `REQ-08` | `CON-04`, `CON-06`, `CTR-01`, `CTR-04`, `CTR-06`, `FM-07` | `EC-02`, `EC-05`, `EC-06`, `SC-03`, `SC-06` | `CHK-02`, `CHK-05`, `CHK-06` | `EVID-02`, `EVID-05`, `EVID-06` |

### Acceptance Scenarios

- `SC-01` Пользователь пишет естественную capture-реплику с одним явным task-intent вроде `надо купить молоко`; routing-слой выдает verdict `capture_task`, передает сообщение в `FT-001`-совместимый capture-path и downstream-ответ сохраняет существующий контракт доверия этой возможности.
- `SC-02` Пользователь пишет retrieval-парафразу вроде `что у меня открыто?`; routing-слой выдает verdict `list_open_tasks`, не создает новую задачу и передает управление в `FT-002`-совместимый retrieval-path.
- `SC-03` В системе существует ровно одна задача с точным текстом `купить молоко`. Пользователь пишет `закрой купить молоко`; routing-слой выставляет `intent_label = mark_task_done`, безопасно резолвит один target и, пока `FT-006` еще не реализован, возвращает verdict со статусом `pending_executor` без capture/retrieval-передачи управления и без видимости успешно измененного статуса.
- `SC-04` Пользователь пишет mixed-intent реплику вроде `покажи задачи и закрой первую`; routing слой не выполняет частичное действие и возвращает clarification verdict с просьбой разделить или уточнить запрос.
- `SC-05` Пользователь пишет запрос вне scope вроде `что я говорил про корову месяц назад?`; routing-слой возвращает явный unsupported verdict без побочных изменений состояния и без ложного впечатления, что assistant что-то нашел или изменил.
- `SC-06` Пользователь пишет `удали купить молоко`, но в системе есть несколько задач с таким текстом или target не определен безопасно; routing-слой выставляет `intent_label = delete_task`, но оставляет `resolution_status = clarification_needed` и не выдает destructive handoff.

### Checks

Verify должен быть исполнимым.

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `EC-04`, `SC-01`, `SC-02` | Прогнать детерминированную routing-спецификацию на корпусе supported capture и retrieval paraphrases с подставными downstream-обработчиками `FT-001` и `FT-002` | Capture-реплики получают verdict `capture_task` и `handoff` только в capture-обработчик; retrieval-парафразы получают verdict `list_open_tasks` и `handoff` только в retrieval-обработчик; downstream verdict semantics не подменяются routing-слоем | `artifacts/ft-004/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-03` | Прогнать детерминированную routing-спецификацию на корпусе lifecycle-команд `закрой ...`, `верни ... в работу`, `удали ...` с разными условиями разрешения target и с подставным состоянием исполнителя | Каждая lifecycle-реплика получает соответствующий lifecycle `intent_label`; capture/retrieval-передача управления не происходит; при единственном safe target verdict может перейти только в `pending_executor`, а не в outcome, похожий на успех | `artifacts/ft-004/verify/chk-02/` |
| `CHK-03` | `EC-03`, `SC-04`, `SC-05`, `NEG-01`, `NEG-02`, `NEG-03` | Прогнать детерминированную routing-спецификацию на mixed-intent, ambiguous и запросах вне scope; проверить итоговый пользовательский verdict и отсутствие побочных действий обработчиков | Routing возвращает clarification или unsupported verdict, не вызывает downstream-путь с изменением состояния и явно сообщает, что действие не выполнено | `artifacts/ft-004/verify/chk-03/` |
| `CHK-04` | `EC-04`, `SC-01`, `SC-02` | Прогнать интеграционную проверку на уровне контракта с реальными или equivalent downstream stubs `FT-001` и `FT-002`, сравнив пользовательскую success/failure semantics до и после добавления routing-слоя | Для уже supported capture/retrieval-сценариев routing не меняет контракт доверия downstream-возможности, кроме выбора самого обработчика | `artifacts/ft-004/verify/chk-04/` |
| `CHK-05` | `EC-05`, `SC-03` | Прогнать lifecycle-intent сценарии в конфигурации без `FT-006`-исполнителя и проверить пользовательский verdict | Пользователь не получает сообщение, похожее на успешное `done` / `reopen` / `delete`; task state остается без изменений | `artifacts/ft-004/verify/chk-05/` |
| `CHK-06` | `EC-06`, `SC-06`, `NEG-04` | Прогнать детерминированную спецификацию разрешения цели для удаления на ambiguous, missing и multiply-matched targets | Для `delete_task` при любой неуверенности verdict остается `clarification_needed`, destructive handoff отсутствует, task state не меняется | `artifacts/ft-004/verify/chk-06/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-004/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-004/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-004/verify/chk-03/` |
| `CHK-04` | `EVID-04` | `artifacts/ft-004/verify/chk-04/` |
| `CHK-05` | `EVID-05` | `artifacts/ft-004/verify/chk-05/` |
| `CHK-06` | `EVID-06` | `artifacts/ft-004/verify/chk-06/` |

### Evidence

- `EVID-01` Артефакт successful routing для supported capture и retrieval intents.
- `EVID-02` Артефакт классификации lifecycle-intent без unintended handoff.
- `EVID-03` Артефакт покрытия безопасности для mixed-intent / ambiguous / unsupported routing.
- `EVID-04` Артефакт contract-preservation check для downstream capture/retrieval semantics.
- `EVID-05` Артефакт lifecycle-pending verdict, подтверждающий отсутствие ложного статуса успеха.
- `EVID-06` Артефакт strict delete clarification coverage при неуверенном target resolution.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Структурированный вывод routing-спецификации для supported capture/retrieval paraphrases | verify-runner | `artifacts/ft-004/verify/chk-01/` | `CHK-01` |
| `EVID-02` | Структурированный вывод routing-спецификации для распознавания lifecycle intent | verify-runner | `artifacts/ft-004/verify/chk-02/` | `CHK-02` |
| `EVID-03` | Структурированный вывод routing-спецификации для mixed-intent, ambiguous и unsupported inputs | verify-runner | `artifacts/ft-004/verify/chk-03/` | `CHK-03` |
| `EVID-04` | Структурированный интеграционный вывод, сравнивающий routing handoff с canonical downstream semantics | verify-runner | `artifacts/ft-004/verify/chk-04/` | `CHK-04` |
| `EVID-05` | Структурированный verify-вывод для lifecycle-intent в режиме без downstream-исполнителя | verify-runner | `artifacts/ft-004/verify/chk-05/` | `CHK-05` |
| `EVID-06` | Структурированный verify-вывод для строгих правил clarification при удалении | verify-runner | `artifacts/ft-004/verify/chk-06/` | `CHK-06` |

### Negative Scenarios

- `NEG-01` Реплика одновременно похожа на retrieval и lifecycle intent; routing не должен частично исполнять один из них без clarification.
- `NEG-02` Реплика содержит два действия вроде `добавь купить молоко и покажи задачи`; routing не должен выполнять capture и игнорировать вторую часть.
- `NEG-03` Реплика выходит за narrow task-action scope `PRD-002`; routing не должен придумывать близкий supported intent и запускать side effects.
- `NEG-04` Пользователь просит удалить задачу, но target не уникален или не найден; routing не должен выполнять guessed delete и обязан остановиться на clarification.
