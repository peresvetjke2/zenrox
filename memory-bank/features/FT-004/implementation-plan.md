---
title: "FT-004: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-004. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: active
audience: humans_and_agents
must_not_define:
  - ft_004_scope
  - ft_004_architecture
  - ft_004_acceptance_criteria
  - ft_004_blocker_state
---

# План имплементации

## Цель текущего плана

Добавить первый owner-слой conversational intent routing поверх существующего Rails backend и текущего Telegram conversational channel: текстовая реплика должна сначала получать детерминированный routing verdict из taxonomy `FT-004`, затем либо безопасно делегироваться в already-implemented capture/retrieval capability, либо останавливаться на explicit `clarification_needed`, `unsupported` или `pending_executor` без ложного эффекта успешного действия.

## Current State / Reference Points

План заземлен в текущем состоянии репозитория: conversational routing сейчас фактически живет внутри `Interaction::TelegramWebhook`, retrieval распознается только по exact-команде `задачи`, а все остальные текстовые сообщения по умолчанию уходят в `Capture::ProcessMessage`. `FT-004` должен вынести intent selection в отдельный owner-слой, не сломав existing trust contracts `FT-001` и `FT-002`.

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `memory-bank/features/FT-004/feature.md` | Canonical owner scope, routing taxonomy, verdict contract и verify inventory | Все execution-решения должны ссылаться на `REQ-*`, `CTR-*`, `CHK-*`, `EVID-*` отсюда | Использовать как единственный source of truth для routing semantics |
| `memory-bank/prd/PRD-002-conversational-routing-for-core-assistant-actions.md` | Product-level intent taxonomy, trust rules и downstream split между `FT-004`, `FT-005`, `FT-006` | Нужен, чтобы не затянуть в `FT-004` list-based references или real lifecycle execution | Mirror narrow single-intent scope и strict ambiguity handling |
| `memory-bank/use-cases/UC-004-task-status-lifecycle.md` | Draft upstream flow для lifecycle-intents и safe clarification | Нужен для `mark_task_done`, `reopen_task`, `delete_task` без premature executor design | Reuse only scenario intent, не стабилизируя исполнение beyond draft |
| `app/services/interaction/telegram_webhook.rb` | Current conversational entrypoint; exact `задачи` routed to retrieval, всё остальное text -> capture | Здесь routing должен стать thin transport orchestration, а не owner intent logic | Mirror pattern `transport -> owner service -> reply` |
| `app/services/capture/process_message.rb` | Existing owner orchestration для single-task capture | `FT-004` не должен менять admission semantics `FT-001`; только выбирать, когда этот путь вызывать | Reuse as capture downstream owner unchanged |
| `app/services/retrieval/list_open_tasks.rb` | Existing owner orchestration для open-tasks retrieval | `FT-004` не должен менять retrieval result contract `FT-002`; только выбирать, когда этот путь вызывать | Reuse as retrieval downstream owner unchanged |
| `app/services/capture/result.rb` | Canonical capture verdict vocabulary и JSON contract | Нужен для contract-preservation checks и для explicit separation между routing verdict и downstream result | Mirror without rewording `accepted/rejected/failed` semantics |
| `app/services/retrieval/result.rb` | Canonical retrieval text contract | Нужен, чтобы routing не начал форматировать retrieval success ad hoc | Preserve exact retrieval reply wording |
| `app/models/task.rb` | Current task source of truth with statuses `open` / `done` and stable retrieval scope | Нужен для safe exact-text target resolution и ambiguity detection для lifecycle intents | Reuse current persistence owner without new schema |
| `spec/requests/telegram_webhooks_spec.rb` | Existing transport-level deterministic coverage и evidence-writing pattern | Здесь удобнее всего доказать contract-preserving handoff и отсутствие unintended side effects | Mirror request-spec style и artifact writing |
| `spec/requests/captures_spec.rb` | Existing direct capture contract coverage | Нужен как baseline downstream semantics, которые routing не должен ломать | Reuse assertion style для compare-before/after handoff |
| `spec/services/retrieval/list_open_tasks_spec.rb` | Existing retrieval owner coverage | Нужен как baseline retrieval semantics для `CHK-04` | Reuse spec style и exact reply assertions |
| `spec/support/evidence_helper.rb` | Existing canonical evidence writer | Нужен для `artifacts/ft-004/verify/chk-*/` без нового plumbing | Reuse helper as-is |
| `memory-bank/ops/development.md` | Canonical local setup/test commands | План должен ссылаться на реальные команды Rails/RSpec, а не на шаблонные предположения | Reuse documented `mise` + `bundle exec rspec` command |
| `memory-bank/engineering/testing-policy.md` | Policy-level rules для deterministic routing coverage и manual-only gaps | `FT-004` полностью детерминирован на локальном backend и не должен уходить в manual-only verify | Mirror automated-first verify discipline |

## Test Strategy

CI для проекта пока не адаптирован, поэтому required CI suites фиксируются как `none`; локальный deterministic verify обязателен для всех `CHK-01`..`CHK-06`.

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Routing owner: supported capture/retrieval paraphrases, single verdict taxonomy и explicit non-success routing replies | `REQ-01`, `REQ-02`, `REQ-03`, `REQ-05`, `REQ-06`, `SC-01`, `SC-02`, `SC-04`, `SC-05`, `CHK-01`, `CHK-03`, `CHK-04` | Нет | Новый service spec на routing verdict, explicit handoff selection и deterministic reply payload/presenter for `clarification_needed` / `unsupported` / `pending_executor` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| Routing owner: lifecycle intent detection, exact-text target resolution и `pending_executor` behavior | `REQ-04`, `REQ-07`, `REQ-08`, `SC-03`, `SC-06`, `CHK-02`, `CHK-05`, `CHK-06` | Нет | Новый service spec на `mark_task_done` / `reopen_task` / `delete_task`, including unique, missing и duplicate target cases | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| Routing owner: mixed-intent, ambiguity и unsupported safety coverage | `REQ-05`, `REQ-06`, `NEG-01`, `NEG-02`, `NEG-03`, `NEG-04`, `CHK-03`, `CHK-06` | Нет | Новый service spec на clarification/unsupported verdicts и explicit absence of downstream handoff | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| Telegram transport integration with routing owner | `ASM-01`, `REQ-03`, `SC-01`, `SC-02`, `SC-03`, `SC-04`, `SC-05`, `SC-06`, `CHK-04`, `CHK-05` | Current request spec покрывает exact retrieval command и capture fallback, но не общий routing owner contract | Request specs на conversational paraphrases, lifecycle pending verdict, clarification/unsupported replies, capture rejected/failed passthrough, retrieval failure passthrough и absence of unintended `Task` mutations | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |

## Open Questions / Ambiguities

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | Должен ли новый routing owner вызываться только из текущего Telegram conversational path или сразу иметь transport-agnostic интерфейс для будущих non-Telegram entrypoints | В кодовой базе сегодня есть только Telegram conversational surface, но `FT-004` формулируется как owner intent layer, который позже пригодится и вне transport-specific branch | Не блокирует реализацию; влияет на naming и placement нового service | По умолчанию делать transport-agnostic service в `app/services/routing/`, а Telegram оставить thin adapter-ом; owner: agent |
| `OQ-02` | Нужно ли на этапе `FT-004` ограничивать exact-text lifecycle target resolution только задачами в ожидаемом статусе (`open` для `mark_task_done`, `done` для `reopen_task`) или достаточно выявлять uniqueness across all tasks | `FT-004` не исполняет lifecycle action и опирается на draft `UC-004`, поэтому жесткая status-semantic фильтрация может преждевременно закрепить downstream behavior `FT-006` | `STEP-03`, `STEP-04` | По умолчанию routing доказывает только safe target uniqueness и не симулирует domain transition rules beyond current feature; owner: agent |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | Локально доступны `mise`, `ruby 3.4.8`, `bundle`, Rails app и PostgreSQL baseline из `memory-bank/ops/development.md` | `STEP-01`..`STEP-06` | Specs или `rails db:prepare` не запускаются, `Task` storage не поднимается |
| test | Canonical local verify command на этом этапе: `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `CHK-01`..`CHK-06` | Локальный verify нельзя честно считать завершенным |
| access / network / secrets | Для deterministic реализации `FT-004` live Telegram credentials и сеть не нужны; request specs используют stubbed config/client | `STEP-03`, `STEP-04`, `STEP-05` | Если для базового verify требуется live Telegram или network access, значит transport boundary спроектирован неверно |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-01` | `ASM-02`, `CON-03`, `INV-03` | `FT-001` и `FT-002` остаются canonical owner-ами capture/retrieval semantics и не должны меняться ради `FT-004` | `STEP-02`, `STEP-04`, `STEP-05` | yes |
| `PRE-02` | `ASM-01`, `CON-01` | Current conversational surface остается text-first и routing не требует нового клиента или UI | `STEP-01`, `STEP-05` | yes |
| `PRE-03` | `CON-02`, `INV-01`, `INV-02` | Safety-first behavior при ambiguity и lifecycle intents имеет приоритет над recall и convenience | `STEP-02`, `STEP-03`, `STEP-05` | yes |
| `PRE-04` | `CON-04`, `CON-05`, `INV-05` | До `FT-005` безопасное target resolution ограничено exact-text matching against current tasks; при неуверенности нужен clarification verdict | `STEP-03`, `STEP-04`, `STEP-05` | yes |
| `PRE-05` | `CON-06`, `EC-05` | До появления `FT-006` lifecycle intents могут дойти максимум до `pending_executor`, а не до real state change | `STEP-03`, `STEP-05` | yes |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01`, `REQ-02`, `REQ-05`, `REQ-06`, `CTR-01`, `CTR-05`, `CTR-06` | Новый routing owner-layer с explicit verdict object, deterministic non-success reply payload и safety semantics | agent | `PRE-02`, `PRE-03` |
| `WS-2` | `REQ-03`, `REQ-04`, `REQ-07`, `REQ-08`, `CTR-02`, `CTR-03`, `CTR-04` | Contract-preserving handoff в capture/retrieval и lifecycle pending/clarification path | agent | `WS-1`, `PRE-01`, `PRE-04`, `PRE-05` |
| `WS-3` | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05`, `CHK-06` | Deterministic specs, evidence artifacts и transport-level regression protection | agent | `WS-1`, `WS-2` |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | none | none | `FT-004` не требует рискованных, необратимых или внешне-эффективных действий для code-complete verify | none |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `WS-1`, `WS-2` | Зафиксировать final local execution boundary: routing owner живет вне transport, `/capture` route остается canonical FT-001 path, Telegram становится thin conversational adapter | `memory-bank/features/FT-004/*`, `app/services/interaction/telegram_webhook.rb`, `app/controllers/captures_controller.rb` | Актуальный derived plan и clear boundary decisions | `none` | `none` | Doc review + changed-file inspection | `PRE-01`, `PRE-02` | none | Для реализации нужен новый public endpoint, новый client surface или изменение downstream contracts |
| `STEP-02` | agent | `REQ-01`, `REQ-02`, `REQ-05`, `REQ-06`, `CTR-01`, `CTR-05`, `CTR-06` | Реализовать routing verdict model и owner service для taxonomy, ambiguity/unsupported handling, explicit no-handoff outcomes и user-facing routing reply payload для non-success verdicts | `app/services/routing/*` | Routing owner-layer, возвращающий deterministic verdict object и explicit reply payload вне downstream handlers | `CHK-01`, `CHK-03` | `EVID-01`, `EVID-03` | Routing service specs with stubbed downstream handlers | `STEP-01`, `PRE-03`, `OQ-01` | none | Verdict model начинает дублировать downstream payloads или требует transport-specific branches внутри owner service |
| `STEP-03` | agent | `REQ-04`, `REQ-07`, `REQ-08`, `CTR-04` | Добавить lifecycle intent detection и safe exact-text target resolution без исполнения state transition | `app/services/routing/*`, `app/models/task.rb` при необходимости query helper-only changes | Lifecycle-aware routing branch с `pending_executor` и `clarification_needed` | `CHK-02`, `CHK-05`, `CHK-06` | `EVID-02`, `EVID-05`, `EVID-06` | Routing service specs on unique/missing/duplicate targets | `STEP-02`, `PRE-04`, `PRE-05`, `OQ-02` | none | Для safe target resolution требуется новый schema field, conversational numbering или hidden mutation |
| `STEP-04` | agent | `REQ-03`, `CTR-02`, `CTR-03`, `CTR-04`, `EC-04`, `EC-05` | Встроить routing owner в Telegram conversational entrypoint и сохранить capture/retrieval semantics unchanged | `app/services/interaction/telegram_webhook.rb`, возможно `app/controllers/telegram_webhooks_controller.rb` без public contract drift | Updated Telegram orchestration with routing handoff and explicit non-success replies | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05`, `CHK-06` | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-04`, `EVID-05`, `EVID-06` | Request specs for paraphrases, lifecycle pending and clarification/unsupported replies | `STEP-02`, `STEP-03`, `PRE-01` | none | Telegram layer снова начинает содержать intent taxonomy or user-facing lifecycle success simulation |
| `STEP-05` | agent | `WS-3` | Добавить deterministic specs и structured evidence outputs по canonical paths `FT-004` для service- и transport-level coverage, включая passthrough existing capture/retrieval failure semantics | `spec/services/routing/*`, `spec/requests/telegram_webhooks_spec.rb`, `spec/support/evidence_helper.rb`, `artifacts/ft-004/verify/` | Green regression coverage и evidence artifacts | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05`, `CHK-06` | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-04`, `EVID-05`, `EVID-06` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `STEP-04` | none | Tests требуют live Telegram, nondeterministic corpus или не доказывают absence of unintended handoff |
| `STEP-06` | agent | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05`, `CHK-06` | Провести отдельный simplify review после green tests и зафиксировать final evidence/handoff state | changed routing/telegram/spec files, feature package docs | Final code-quality pass и честный verify summary | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05`, `CHK-06` | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-04`, `EVID-05`, `EVID-06` | Separate simplify review after functional verify | `STEP-05` | none | Simplify review выявляет, что routing abstraction избыточна или смешивает owner boundaries |

## Parallelizable Work

- `PAR-01` После фиксации verdict shape в `STEP-02` можно параллельно собирать service-spec corpus для supported и negative routing cases, потому что write-surface не конфликтует с transport integration.
- `PAR-02` `STEP-03` и `STEP-04` не стоит вести как независимые несогласованные edits: Telegram adapter должен опираться на уже выбранный routing owner contract, а не формировать lifecycle behavior напрямую.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`, `PRE-01`, `PRE-02` | Execution boundary зафиксирован: routing owner вынесен из transport, `/capture` и retrieval owners остаются canonical | `none` |
| `CP-02` | `STEP-02`, `CHK-01`, `CHK-03` | Routing owner детерминированно различает supported, ambiguous и unsupported inputs без unintended handoff | `EVID-01`, `EVID-03` |
| `CP-03` | `STEP-03`, `CHK-02`, `CHK-05`, `CHK-06` | Lifecycle intent detection работает отдельно от capture/retrieval и не симулирует успешный executor | `EVID-02`, `EVID-05`, `EVID-06` |
| `CP-04` | `STEP-04`, `CHK-04` | Telegram conversational path переиспользует routing owner и downstream contracts без изменения existing success semantics | `EVID-04` |
| `CP-05` | `STEP-05`, `STEP-06` | Все automated checks зелёные, artifacts записаны в canonical paths, simplify review завершен отдельным проходом | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-04`, `EVID-05`, `EVID-06` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | Intent taxonomy останется частично зашитой в `Interaction::TelegramWebhook` | Routing owner потеряет reusable boundary и tests будут зависеть от transport specifics | Вынести intent selection и verdict shape в отдельный `app/services/routing/` owner-layer | В request spec приходится повторно проверять ветвистую routing-логику без service seam |
| `ER-02` | Retrieval paraphrases будут распознаваться ценой изменения `FT-002` result contract | Сломается contract-preservation invariant `INV-03` | Держать paraphrase recognition в routing owner, а retrieval reply формировать existing `Retrieval::Result` | Появляются новые retrieval success wordings вне `FT-002` |
| `ER-03` | Lifecycle intent detection начнет подменять собой `FT-006` и закрепит premature executor semantics | Scope `FT-004` расползется в state transitions и domain rules | Остановиться на `pending_executor` / clarification, не менять `Task` state и не фиксировать full transition rules | Появляется соблазн обновлять `status` или удалять запись в этой фиче |
| `ER-04` | Exact-text target resolution окажется слишком хрупким и подтолкнет к внедрению context-local numbering внутри `FT-004` | Нарушится downstream split между `FT-004` и `FT-005` | Использовать only exact-text uniqueness сейчас; list-based refs оставить downstream | Для закрытия tests требуется numbering state или shortlist memory |
| `ER-05` | Negative coverage не докажет отсутствие unintended handoff и ложного успеха | Safety claims `FT-004` останутся недоказанными | Явно проверять, какие downstream handlers были вызваны, и что `Task` storage не менялся | Tests ассертят только reply text без side-effect assertions |
| `ER-06` | Routing non-success replies начнут формироваться частично в owner service, частично в Telegram adapter | Verdict contract станет неоднозначным и хуже переносимым на будущие conversational surfaces | Держать explicit routing reply payload рядом с routing verdict, а transport использовать только как delivery adapter | Clarification/unsupported wording зависит от конкретного transport branch-а |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `PRE-01`, `ER-02`, `ER-03` | Для реализации routing требуется менять canonical capture/retrieval contracts или исполнять lifecycle state transition внутри `FT-004` | Остановить code changes и поднять upstream update сначала в `feature.md` / PRD / downstream feature split | Existing `FT-001` / `FT-002` behavior остается рабочим без half-implemented routing |
| `STOP-02` | `PRE-04`, `ER-04` | Exact-text target resolution недостаточно, и для продолжения нужен context-local reference mechanism | Не добавлять numbering ad hoc; остановить исполнение и поднимать change в `FT-005` / `PRD-002` | Routing остается ограниченным capture/retrieval + lifecycle clarification |
| `STOP-03` | `PRE-03`, `ER-05` | Verify нельзя сделать детерминированным без live transport или ручных прогонов | Не подменять automated coverage manual smoke-check-ом; пересобрать seams и test harness | Codebase остается без claim о завершенном routing safety contract |

## Готово для приемки

План считается исчерпанным, когда:

- `STEP-01..06` завершены без активных stop conditions;
- локально пройдены `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05`, `CHK-06`;
- в `artifacts/ft-004/verify/chk-01/` .. `chk-06/` лежат соответствующие structured outputs;
- Telegram conversational path использует routing owner как thin adapter, не ломая contracts `FT-001` и `FT-002`;
- lifecycle intents до `FT-006` останавливаются на `pending_executor` или `clarification_needed`, не маскируясь под applied state change;
- simplify review выполнен отдельным проходом после functional verify.
