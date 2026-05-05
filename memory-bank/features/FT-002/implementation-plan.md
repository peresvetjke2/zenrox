---
title: "FT-002: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-002. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_002_scope
  - ft_002_architecture
  - ft_002_acceptance_criteria
  - ft_002_blocker_state
---

# План имплементации

## Цель текущего плана

Добавить первый retrieval slice поверх уже существующего Rails backend и Telegram transport: точная команда `задачи` должна маршрутизироваться в read-only retrieval-path, возвращать стабильный список `open`-задач или явный deterministic verdict, не уходить в capture-path и не менять `Task` storage.

## Current State / Reference Points

План заземлен в текущем состоянии репозитория: backend, `Task` storage, Telegram webhook и deterministic request-spec harness уже существуют благодаря `FT-001` и `FT-003`, поэтому `FT-002` должен расширять established boundaries, а не вводить новый public transport.

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `memory-bank/features/FT-002/feature.md` | Canonical scope, reply contract, verify и failure modes retrieval slice | Все execution-решения должны ссылаться на `REQ-*`, `CTR-*`, `CHK-*`, `EVID-*` отсюда | Использовать как единственный source of truth для retrieval semantics |
| `memory-bank/use-cases/UC-007-open-tasks-retrieval.md` | Scenario-level flow и exception semantics retrieval | Нужен для main flow, empty-state и read-failure behavior | Зеркалить `ALT-01`, `ALT-02`, `EX-01` в user-visible verdicts |
| `app/services/interaction/telegram_webhook.rb` | Current phone-friendly interaction layer; сейчас все текстовые сообщения идут в capture-path | Здесь должен появиться явный retrieval branch только для точной команды `задачи` до вызова capture service | Mirror existing thin interaction orchestration without persistence logic inside controller |
| `app/services/capture/process_message.rb` | Existing owner orchestration для capture semantics | `FT-002` не должен ломать capture behavior и не должен пропускать retrieval-команду сюда | Reuse boundary pattern `interaction -> owner service -> result` |
| `app/models/task.rb` | Current source of truth для task records со статусами `open` и `done` | Retrieval filtering и stable ordering должны строиться поверх current model contract | Reuse `Task` как owner-layer без transport-specific knowledge |
| `db/schema.rb` | Показывает доступные persistent fields, включая `status` и `created_at`/`id` ordering context | Нужен для выбора deterministic retrieval ordering и failure-free read-path без schema drift | Опираться на существующую schema, не вводя лишние поля для первого retrieval slice |
| `spec/requests/telegram_webhooks_spec.rb` | Existing deterministic transport-level coverage и evidence pattern для Telegram surface | `CHK-03` и часть read-only invariants удобнее всего доказывать здесь | Mirror request-spec style и `write_evidence(..., feature: "ft-002")` |
| `spec/support/evidence_helper.rb` | Existing artifact writer для canonical evidence paths | Нужен для сохранения structured verify outputs по `FT-002` | Reuse existing helper without new artifact plumbing |
| `memory-bank/ops/development.md` | Canonical local setup/test commands | План должен ссылаться на реальные команды, а не на шаблонные допущения | Reuse documented `mise` + `bundle exec rspec` command line |
| `memory-bank/engineering/testing-policy.md` | Policy-level rules для deterministic coverage и manual-only gaps | Retrieval filtering, routing и read-failure детерминированы, значит должны иметь automated coverage | Mirror policy: live Telegram smoke остается только для `CHK-04` |

## Test Strategy

CI для проекта пока не адаптирован, поэтому required CI suites фиксируются как `none`; локальный deterministic verify остается обязательным.

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Retrieval owner service: mixed `open` / `done` set, stable order, no-date tasks | `REQ-02`, `REQ-03`, `REQ-04`, `REQ-08`, `SC-01`, `SC-02`, `CHK-01` | Нет | Новый service spec на deterministic retrieval result, filtering и exact formatted non-empty reply `Открытые задачи:` + `- <task.body>` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| Retrieval owner service: empty backlog и injected read failure | `REQ-05`, `REQ-07`, `REQ-08`, `SC-03`, `SC-06`, `CHK-02`, `CHK-05` | Нет | Service specs на empty-state, storage read failure verdict и read-only invariant | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| Telegram routing for exact `задачи` command | `REQ-01`, `REQ-05`, `REQ-06`, `SC-04`, `CHK-03` | Текущий Telegram request spec покрывает только capture path | Request spec на routing exact command в retrieval, reply delivery и отсутствие новой `Task` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| Live Telegram phone smoke | `REQ-06`, `REQ-07`, `SC-05`, `CHK-04` | Нет | Не автоматизируется локально; остается manual smoke-check после настройки live creds и public webhook URL | `none` | `none` | Реальный Telegram delivery требует live bot token, webhook URL и phone chat вне локального deterministic harness | `AG-01` |

## Open Questions / Ambiguities

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | Достаточно ли одного owner service, который и читает `Task`, и форматирует deterministic textual verdict, или formatter стоит выделить отдельно | В кодовой базе еще нет retrieval patterns, а `CTR-03` задает явный text contract вплоть до строк `- <task.body>` | Не блокирует весь план; влияет на granularity `STEP-02` | По умолчанию начать с minimal service boundary, выделять отдельный formatter только если это упростит tests без лишней абстракции; owner: agent |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | Локально доступны `mise`, `ruby 3.4.8`, `bundle`, Rails app и PostgreSQL baseline из `memory-bank/ops/development.md` | `STEP-01`..`STEP-05` | Specs или `rails db:prepare` не запускаются, `Task` storage не поднимается |
| test | Canonical local verify command на этом этапе: `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-05` | Локальный verify нельзя честно считать завершенным |
| access / network / secrets | Для deterministic code-complete состояния live Telegram credentials не нужны; для `CHK-04` нужны `ZENROX_TELEGRAM_BOT_TOKEN`, optional `ZENROX_TELEGRAM_SECRET_TOKEN`, optional `ZENROX_TELEGRAM_ALLOWED_CHAT_ID` и публичный webhook URL | `STEP-05`, `CHK-04` | Без live creds/manual infra phone smoke-check остается открытым и не должен маскироваться под completed evidence |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-01` | `ASM-01`, `CON-03` | `Task` model и statuses `open` / `done` уже являются owner-layer source of truth для retrieval | `STEP-02`, `STEP-03`, `STEP-04` | yes |
| `PRE-02` | `ASM-02`, `REQ-06`, `CTR-01` | Current Telegram conversational surface уже существует и может быть расширена retrieval branch-ом без нового client channel | `STEP-01`, `STEP-03`, `STEP-04` | yes |
| `PRE-03` | `CON-02`, `INV-01`, `CTR-04` | Retrieval-path остается strictly read-only относительно task storage | `STEP-02`, `STEP-03`, `STEP-04` | yes |
| `PRE-04` | `REQ-08`, `CTR-03`, `CTR-05` | User-visible reply contract из sibling `feature.md` считается canonical и не переопределяется в коде ad hoc | `STEP-02`, `STEP-03`, `STEP-04` | yes |
| `PRE-05` | `CON-06`, `CHK-04` | Live Telegram smoke допускается только как manual-only gap с отдельным approval | `STEP-05` | no |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-02`, `REQ-03`, `REQ-04`, `REQ-08`, `CTR-02`, `CTR-03`, `CTR-05` | Owner retrieval service с deterministic filtering, ordering, formatting, empty-state и read-failure verdicts | agent | `PRE-01`, `PRE-03`, `PRE-04` |
| `WS-2` | `REQ-01`, `REQ-05`, `REQ-06`, `CTR-01`, `CTR-04` | Telegram routing exact command `задачи` в retrieval-path и отсутствие capture side effects | agent | `WS-1`, `PRE-02` |
| `WS-3` | `REQ-07`, `CHK-01`, `CHK-02`, `CHK-03`, `CHK-04`, `CHK-05` | Automated specs, evidence artifacts и честно зафиксированный manual-only live gap | agent | `WS-1`, `WS-2`, `PRE-05` |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | Запуск live Telegram smoke-check через реальный чат, bot token и public webhook URL | `CHK-04`, `STEP-05` | Это внешне-эффективное действие и зависит от live credentials / публичной delivery surface | user approval + manual evidence in `artifacts/ft-002/verify/chk-04/` |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `WS-1`, `WS-2` | Зафиксировать final local design choices для retrieval path без scope drift: no new public route, reuse Telegram interaction boundary, owner retrieval service over `Task` | `memory-bank/features/FT-002/*`, `app/services/interaction/telegram_webhook.rb`, `app/models/task.rb` | Актуальный derived plan и clear execution boundary | `none` | `none` | Doc review + changed-file inspection | `PRE-01`, `PRE-02` | none | Если для реализации внезапно требуется новый public contract beyond sibling `feature.md` |
| `STEP-02` | agent | `REQ-02`, `REQ-03`, `REQ-04`, `REQ-05`, `REQ-08`, `CTR-02`, `CTR-03`, `CTR-04`, `CTR-05` | Реализовать owner retrieval service над `Task`: stable `open` filtering, exact non-empty text contract `Открытые задачи:` + `- <task.body>`, empty-state, read-failure verdict и zero mutation semantics | `app/services/retrieval/`, `app/models/task.rb` при необходимости read-only query helpers | Retrieval owner service и minimal result/formatter boundary | `CHK-01`, `CHK-02`, `CHK-05` | `EVID-01`, `EVID-02`, `EVID-05` | Service specs на mixed set, empty backlog и injected read failure | `STEP-01`, `PRE-01`, `PRE-03`, `PRE-04` | none | Для deterministic read failure нужна upstream contract change или write-like workaround |
| `STEP-03` | agent | `REQ-01`, `REQ-05`, `REQ-06`, `REQ-08`, `CTR-01`, `CTR-04` | Встроить retrieval routing в Telegram interaction: exact `задачи` -> retrieval service, остальные тексты -> existing capture path | `app/services/interaction/telegram_webhook.rb`, возможно `app/controllers/telegram_webhooks_controller.rb` без contract drift | Updated Telegram interaction orchestration | `CHK-03` | `EVID-03` | Telegram request specs с stubbed client и task-count assertions | `STEP-02`, `PRE-02`, `PRE-03`, `PRE-04` | none | Exact command branch начинает дублировать retrieval/capture semantics в transport instead of delegating to owner services |
| `STEP-04` | agent | `REQ-07`, `CHK-01`, `CHK-02`, `CHK-03`, `CHK-05` | Добавить/обновить deterministic specs и сохранить structured evidence artifacts по canonical paths `FT-002` | `spec/services/`, `spec/requests/telegram_webhooks_spec.rb`, `spec/support/evidence_helper.rb`, `artifacts/ft-002/verify/` | Green automated coverage и evidence files для local checks | `CHK-01`, `CHK-02`, `CHK-03`, `CHK-05` | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-05` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `STEP-02`, `STEP-03` | none | Tests оказываются nondeterministic, не покрывают read-only invariants или требуют live Telegram |
| `STEP-05` | agent | `REQ-07`, `CHK-04` | Выполнить отдельный simplify review, затем зафиксировать manual-only live Telegram gap и readiness к user-run smoke-check | changed retrieval/telegram files, `artifacts/ft-002/verify/chk-04/` | Final code-quality pass и честный acceptance handoff | `CHK-04` | `EVID-04` | Separate simplify review after green tests; manual smoke only after explicit approval | `STEP-04`, `PRE-05` | `AG-01` | Для полного closure требуют live phone proof без доступных creds/public webhook surface |

## Parallelizable Work

- `PAR-01` После стабилизации `STEP-02` service-spec corpus и evidence payload shape можно готовить параллельно с Telegram routing tests, потому что write-surface не пересекается.
- `PAR-02` `STEP-02` и `STEP-03` не стоит вести как независимые несогласованные edits: Telegram branch должен делегировать в уже выбранный retrieval owner contract, а не формировать reply напрямую.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01`, `REQ-06`, `ER-04` | Execution boundary зафиксирован: retrieval идет через owner service и existing Telegram surface без нового public endpoint | `none` |
| `CP-02` | `STEP-02`, `CHK-01`, `CHK-02`, `CHK-05` | Owner retrieval service детерминированно отдает mixed-status list, empty-state и read-failure verdict без mutation | `EVID-01`, `EVID-02`, `EVID-05` |
| `CP-03` | `STEP-03`, `CHK-03` | Telegram interaction отличает exact command `задачи` и existing capture flow без cross-path leakage | `EVID-03` |
| `CP-04` | `STEP-04` | Все automated checks `CHK-01`, `CHK-02`, `CHK-03`, `CHK-05` проходят локально, а artifacts записаны в canonical paths | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-05` |
| `CP-05` | `STEP-05`, `CHK-04` | Simplify review завершен отдельным проходом, а live Telegram gap оставлен только как explicit human-approved smoke-check | `EVID-04` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | Exact command routing случайно протечет в existing capture admission и вернет capture rejection вместо retrieval semantics | Нарушает `REQ-01` и размывает product contract | Делать retrieval branching в Telegram interaction до `Capture::ProcessMessage.call` и покрыть request spec-ом | `задачи` начинает идти через capture verdict vocabulary |
| `ER-02` | Retrieval formatting будет собран ad hoc в transport-слое, а не в owner service/result boundary | Усложнит reuse и сделает `CHK-01`/`CHK-03` зависимыми от transport details | Держать deterministic textual contract рядом с retrieval owner service и тестировать его без live transport | В request spec приходится ассертить длинный inline formatter без service-level evidence |
| `ER-03` | Read failure coverage останется непротестированной из-за неудобной точки инъекции | Оставит незакрытым расхождение между `UC-007 EX-01` и feature verify | Сразу проектировать retrieval service с injectable reader/query dependency или equivalent stub seam | Не получается воспроизвести read failure без ломки Active Record internals |
| `ER-04` | Появится соблазн добавить новый REST endpoint “для удобства тестов” | Увеличит transport surface и выйдет за минимальный scope без продуктовой нужды | Держать deterministic verify на service specs + Telegram request specs, пока upstream не запросит другой surface | Возникает новый route, не нужный для `REQ-06` |
| `ER-05` | Live phone smoke-check будет принят за замену automated coverage | Можно преждевременно считать feature завершенной без regression protection | Явно разделить automated local checks и manual `CHK-04` | Появляется желание закрыть `CHK-01..03,05` только ручным Telegram прогоном |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `REQ-06`, `DEC-01`, `ER-04` | Для реализации retrieval требуют новый public transport contract или изменение external API beyond current docs | Остановить code changes и поднять upstream update сначала в `feature.md`/PRD/use case | Existing capture + Telegram behavior остается рабочим без half-implemented retrieval route |
| `STOP-02` | `PRE-03`, `CTR-05`, `FM-07` | Реализация retrieval требует write-side workaround, mutation или temporary persisted cache | Не вводить обходной write path; остановить исполнение и пересмотреть design upstream | Codebase остается без retrieval feature, но без нарушения read-only invariant |
| `STOP-03` | `AG-01`, `CHK-04` | От пользователя требуют live Telegram proof без approval или без доступной public surface | Не выполнять внешние действия; оставить feature как code-complete с explicit manual-only gap | Локально проверенный код, green automated checks и documented next-step for smoke-check |

## Готово для приемки

План считается исчерпанным, когда:

- `STEP-01..05` завершены без активных stop conditions;
- локально пройдены `CHK-01`, `CHK-02`, `CHK-03`, `CHK-05`;
- в `artifacts/ft-002/verify/chk-01/`, `chk-02/`, `chk-03/`, `chk-05/` лежат соответствующие structured outputs;
- simplify review выполнен отдельным проходом после functional verify;
- live Telegram phone smoke остается только как explicit `AG-01`-guarded шаг для `CHK-04`, а не как замена deterministic coverage.
