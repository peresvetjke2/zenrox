---
title: "FT-001: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-001. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: active
audience: humans_and_agents
must_not_define:
  - ft_001_scope
  - ft_001_architecture
  - ft_001_acceptance_criteria
  - ft_001_blocker_state
---

# План имплементации

## Цель текущего плана

Подготовить и реализовать первый рабочий vertical slice `FT-001` на `Rails 8` с `PostgreSQL` и `RSpec`: один capture endpoint принимает одну текстовую реплику, детерминированно решает `supported` / `rejected`, при supported-входе создает ровно одну `open`-задачу и возвращает user-visible verdict без ложного подтверждения при write failure.

## Current State / Reference Points

План заземлен в текущем состоянии репозитория: прикладной код и runtime bootstrap еще отсутствуют, feature package уже создан и design-ready, а project-level stack conventions пока не адаптированы под реальное приложение.

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `memory-bank/features/FT-001/feature.md` | Canonical owner scope, design, verify и failure modes для capture slice | Все шаги плана обязаны ссылаться на `REQ-*`, `CTR-*`, `FM-*`, `CHK-*`, `EVID-*` отсюда | Использовать как единственный source of truth для scope и verify |
| `memory-bank/use-cases/UC-006-single-task-text-capture.md` | Use-case уровня сценария single-task capture | Нужен для user-facing flow и exception semantics | Зеркалить main/exception flow в endpoint verdicts |
| `memory-bank/prd/PRD-001-first-capture-and-retrieval-loop.md` | Upstream initiative и product boundaries первого MVP | Не дает расползтись в retrieval, reminders и multi-intent parsing | Сохранять `solution-lean` и узкий MVP scope |
| `memory-bank/domain/architecture.md` | Canonical module boundaries и failure-handling rules | Задает ownership между `interaction`, `assistant-orchestration`, `personal-memory` и запрет на success до persistence ack | Разложить Rails-код по этим boundary, а не смешивать parsing, response и persistence в одном controller action |
| `memory-bank/engineering/testing-policy.md` | Policy для deterministic coverage и manual-only gaps | Для `FT-001` parsing и failure-path детерминируемы, значит должны иметь automated coverage | Добавить request/service/model coverage без live AI |
| `memory-bank/engineering/autonomy-boundaries.md` | Границы автономии и supervision checkpoints | Bootstrap нового backend и изменение task model допустимы, но должны быть отражены в плане до кода | Использовать этот план как checkpoint перед реализацией |
| `mise.toml` | Единственный явный runtime hint в репозитории | Уже фиксирует `ruby = "3.4.8"` и позволяет не придумывать версию Ruby с нуля | Опереться на Ruby toolchain из `mise`, не вводить альтернативный runtime |
| `memory-bank/ops/development.md` | Placeholder для project dev/test commands | Пока не адаптирован, поэтому нельзя выдавать вымышленные canonical команды | После bootstrap обновить downstream docs реальными командами, если это войдет в scope |
| repository root | Сейчас содержит только docs/bootstrap файлы без Rails app | Это влияет на sequencing: сначала app bootstrap, затем доменная логика и tests | Не искать несуществующие локальные паттерны; создать минимальный baseline осознанно |

## Test Strategy

На текущем этапе CI еще не задокументирован, поэтому required CI suites фиксируются как ожидаемое будущее зеркало локальных deterministic suites. До появления CI это остается явным project gap, а не молчаливым допущением.

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `POST /capture` happy path | `REQ-01`, `REQ-02`, `REQ-05`, `SC-01`, `CHK-01` | Отсутствует | Request spec на supported single-task inputs; проверка HTTP verdict, response body и persisted `open` task count | `bundle exec rspec` c request specs; при появлении lint отдельно `bundle exec rubocop` | `rspec` suite для request/domain coverage после появления CI | `none` | `none` |
| Admission rule / rejection layer | `REQ-03`, `REQ-05`, `RJ-01`, `NEG-01`, `NEG-02`, `NEG-03`, `CHK-02` | Отсутствует | Service/unit specs на deterministic supported vs unsupported corpus и rejection reasons | `bundle exec rspec` c service specs | `rspec` suite | `none` | `none` |
| Persistence failure path | `REQ-04`, `SC-03`, `NEG-04`, `FM-04`, `CHK-03` | Отсутствует | Request/service specs с deterministic injected write failure и проверкой отсутствия success-like confirmation | `bundle exec rspec` c failure-path specs | `rspec` suite | `none` | `none` |
| `Task` persistence contract | `REQ-01`, `CTR-01`, `INV-01` | Отсутствует | Model spec или equivalent persistence spec на required fields/state для новой `open`-задачи | `bundle exec rspec` | `rspec` suite | `none` | `none` |
| User-visible mobile-ish acceptance transcript | `SC-01`, `SC-02`, `SC-03`, `EVID-01`, `EVID-02`, `EVID-03` | Отсутствует | Structured verify artifacts из automated runs, пригодные для handoff | `bundle exec rspec` + сохраненные verify outputs в `artifacts/ft-001/verify/...` | CI artifact upload после появления CI | Возможна ручная sanity-check под HTTP client, но не как замена automated coverage | `AG-01` |

## Open Questions / Ambiguities

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | Нужен ли отдельный transport/serialization слой сверх минимального API controller + service objects для первого slice | В репозитории еще нет established Rails patterns | Не блокирует весь план; влияет на детализацию `STEP-02` | По умолчанию держать минимальную структуру `controller -> service/result object -> model`, без premature abstraction; owner: agent |
| `OQ-02` | Должен ли `operation_id` быть обязательной частью внешнего HTTP-контракта уже в первом bootstrap | Architecture doc рекомендует idempotency key, но feature doc не фиксирует внешний contract | Может повлиять на shape endpoint и persistence schema | По умолчанию завести внутренне поддерживаемый `operation_id` с серверной генерацией; если понадобится user-supplied idempotency, поднять как upstream change; owner: agent |
| `OQ-03` | Нужно ли в scope этого execution обновлять project-level docs (`ops/development.md`, `engineering/coding-style.md`) после выбора Rails stack | Stack уже выбран для реализации, но project-specific docs пока шаблонные | Не блокирует код, но влияет на completeness handoff | По умолчанию сначала реализовать `FT-001`, затем при необходимости предложить отдельный docs pass или включить минимальные updates в тот же change set, если это не раздует scope; owner: human + agent |
| `OQ-04` | Достаточно ли для `Task` в первом slice полей `body`, `status`, `source_text`, `operation_id`, или потребуется более широкий persistent contract | `feature.md` фиксирует только минимальный capability и не перечисляет storage shape | Может повлиять на migration и на необходимость обновить upstream domain docs | По умолчанию держать минимальный persistence contract; если понадобятся новые устойчивые поля beyond FT-001, сначала поднять это в upstream docs; owner: agent |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | Локально доступны `mise`, `ruby 3.4.8`, `bundle`, `rails`, `psql` или эквивалентный доступ к `PostgreSQL`; Rails app создается внутри текущего repo без выхода за writable roots | `STEP-01`, `STEP-02`, `STEP-03` | `bundle install` / `rails new` / DB setup не выполняются или Ruby version не совпадает |
| test | После bootstrap Rails app локальным verify baseline для backend считается `bundle exec rspec`; при добавлении RuboCop он не заменяет functional verify | `STEP-03`, `STEP-04`, `STEP-05`, `CHK-01`, `CHK-02`, `CHK-03` | Есть код, но нет deterministic green test run на `CHK-01..03` |
| access / network / secrets | Для `FT-001` не требуются live AI keys и внешние интеграции; network может понадобиться только для bootstrap gems, что находится вне текущего плана до явного старта реализации | `STEP-01` | Без network/gem access Rails bootstrap нельзя завершить; в этом случае нужен отдельный approval/escalation шаг перед кодом |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-01` | `ASM-01` | Допустимо реализовывать feature без зафиксированного AI provider и без готового test harness, если capture logic остается deterministic и local-only | `STEP-02`, `STEP-03`, `STEP-04` | no |
| `PRE-02` | `DEC-01`, `CON-01`, `CON-03` | Внутренняя техника interpretation не выбирается как AI-dependent; первый slice реализует conservative deterministic admission rule | `STEP-02`, `STEP-03` | no |
| `PRE-03` | `CTR-01`, `CTR-02`, `CTR-03`, `INV-02` | User-visible verdict формируется только после результата owner-layer persistence | `STEP-03`, `STEP-04`, `STEP-05` | yes |
| `PRE-04` | User decision | Стек для backend зафиксирован как `Rails 8 + PostgreSQL + RSpec` | `STEP-01`, `STEP-02`, `STEP-03`, `STEP-04`, `STEP-05` | yes |
| `PRE-05` | `NS-04`, `memory-bank/engineering/autonomy-boundaries.md` | Task model остается минимальной и не расширяется до richer domain semantics beyond FT-001 без отдельного upstream update | `STEP-03` | no |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01`, `REQ-02`, `REQ-04`, `REQ-05`, `CTR-01`, `CTR-02`, `CTR-03` | Rails backend baseline с минимальной task persistence и capture endpoint | agent | `PRE-04` |
| `WS-2` | `REQ-03`, `REQ-05`, `RJ-01`, `FM-01`, `FM-02`, `FM-03`, `FM-05` | Deterministic admission/rejection layer с объяснимыми verdicts | agent | `WS-1` bootstrap skeleton |
| `WS-3` | `CHK-01`, `CHK-02`, `CHK-03`, `EVID-01`, `EVID-02`, `EVID-03` | Automated regression coverage и verify artifacts для handoff | agent | `WS-1`, `WS-2` |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | Понадобился manual-only verify вместо automated deterministic coverage | `STEP-04`, `WS-3` | Это противоречит default testing policy для rule-like behavior и требует явного принятия gap | human approval в чате |
| `AG-02` | Для bootstrap требуется network/escalated install outside sandbox | `STEP-01` | Это operational action вне чисто локального чтения/редактирования | human approval через sandbox escalation |
| `AG-03` | В ходе реализации выясняется, что `operation_id` или внешний API contract требует product-visible изменения сверх `feature.md` | `STEP-02`, `STEP-03` | Это уже upstream contract change, а не локальная implementation detail | human decision + update в `feature.md` или ADR |
| `AG-04` | Реализация требует расширить task persistence contract beyond minimal fields и `open` state, зафиксированных текущим slice | `STEP-03` | Это уже изменение task model/domain layer, которое по autonomy rules нужно показать на checkpoint, а не вносить молча | human review в чате + при необходимости update upstream docs |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `WS-1` | Забутстрепить Rails backend baseline под текущий repo: app skeleton, Gemfile/tooling, DB config, RSpec setup | repository root, `Gemfile`, `config/`, `app/`, `spec/`, `db/` | Рабочий Rails app skeleton с подключенным RSpec и PostgreSQL | `none` | `none` | Успешный app bootstrap и возможность запустить пустой/базовый `bundle exec rspec` | `PRE-04` | `AG-02` при необходимости | Bootstrap требует неизвестного внешнего сервиса, не помещается в локальный stack или навязывает новый contract |
| `STEP-02` | agent | `REQ-05`, `REQ-03`, `RJ-01`, `FM-01`, `FM-02`, `FM-03`, `FM-05` | Реализовать deterministic admission/rejection слой и contract user-visible verdict для supported/unsupported input | `app/services/`, `app/controllers/`, `app/models/` или equivalent | Capture service/result objects и rejection semantics | `CHK-02` | `EVID-02` | Прогон service/request specs на fixed unsupported corpus и точечные console checks при разработке | `STEP-01`, `PRE-01`, `PRE-02`, `OQ-01`, `OQ-02` | `AG-03` если вылезает новый внешний contract | Conservative rule не удается выразить детерминированно без upstream product decision |
| `STEP-03` | agent | `REQ-01`, `REQ-02`, `REQ-04`, `CTR-01`, `CTR-02`, `CTR-03`, `INV-01`, `INV-02`, `FM-04` | Реализовать persistence path: создание ровно одной `open`-задачи, server-side `operation_id`, success only after save, explicit failed-save response | `db/migrate/`, `app/models/task.rb`, `app/services/`, `app/controllers/` | `Task` schema/model и write path с failure handling | `CHK-01`, `CHK-03` | `EVID-01`, `EVID-03` | Request/model/service specs на happy path и injected write failure | `STEP-01`, `STEP-02`, `PRE-03`, `PRE-05`, `OQ-04` | `AG-03`, `AG-04` при необходимости | Для write failure нужен redesign task model или persistence semantics beyond current feature scope |
| `STEP-04` | agent | `CHK-01`, `CHK-02`, `CHK-03`, `EVID-01`, `EVID-02`, `EVID-03` | Добавить и прогнать deterministic automated coverage, затем сохранить structured verify outputs по каждому canonical check | `spec/`, `artifacts/ft-001/verify/`, changed app files | Зеленые tests и verify outputs для `CHK-01..03` | `CHK-01`, `CHK-02`, `CHK-03` | `EVID-01`, `EVID-02`, `EVID-03` | `bundle exec rspec` и сохранение outputs в `artifacts/ft-001/verify/chk-01/`, `chk-02/`, `chk-03/` | `STEP-02`, `STEP-03` | `AG-01` если coverage внезапно остается manual-only | Tests нестабильны, не покрывают failure modes или требуют live dependency |
| `STEP-05` | agent | `CHK-01`, `CHK-02`, `CHK-03` | Выполнить отдельный simplify review и финальный acceptance pass после green tests, не меняя scope фичи | changed app files, verify artifacts | Упрощенный финальный код и зафиксированный acceptance verdict | `CHK-01`, `CHK-02`, `CHK-03` | `EVID-01`, `EVID-02`, `EVID-03` | Отдельный проход simplify review по changed code, затем подтверждение соответствия `SC-01..03` уже собранным evidence | `STEP-04` | `none` | Для упрощения требуется redesign, который меняет scope, contract или sequencing |

## Parallelizable Work

- `PAR-01` После завершения `STEP-01` часть request spec skeleton и service spec corpus можно готовить параллельно с реализацией persistence, если write surfaces не конфликтуют.
- `PAR-02` `STEP-02` и `STEP-03` логически связаны общим capture contract и не должны вестись как независимые несогласованные ветки внутри одного change set.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01` | Репозиторий содержит рабочий Rails baseline, на котором можно запускать `RSpec` и создавать migration-backed модели | `none` |
| `CP-02` | `STEP-02`, `CHK-02` | Unsupported corpus детерминированно отвергается с explanatory feedback и без persistence side effects | `EVID-02` |
| `CP-03` | `STEP-03`, `CHK-01`, `CHK-03` | Supported input создает ровно одну `open`-задачу, а injected write failure не выдает success-like verdict | `EVID-01`, `EVID-03` |
| `CP-04` | `STEP-04` | Все три canonical checks проходят локально, а verify artifacts сохранены по canonical evidence paths | `EVID-01`, `EVID-02`, `EVID-03` |
| `CP-05` | `STEP-05` | Simplify review завершен отдельным проходом после functional verify; acceptance verdict по `SC-01..03` подтвержден собранными evidence | `EVID-01`, `EVID-02`, `EVID-03` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | Bootstrap Rails/PostgreSQL займет больше времени из-за отсутствия существующего app skeleton | Сдвигает delivery и может смешать infra work с feature logic | Держать bootstrap минимальным: API-only, без лишних integrations, только то, что нужно для `FT-001` | Появляются work items, не связанные напрямую с capture path |
| `ER-02` | Rejection rules быстро расползутся в неформальный NLP | Нарушает `CON-01`/`CON-03` и усложняет verify | Ограничить rule set фиксированным deterministic corpus и conservative heuristics | Возникает желание “немного умнее угадать” ambiguous input |
| `ER-03` | Отсутствие адаптированных project docs по stack создаст разрыв между кодом и документацией | Хуже handoff и локальное воспроизведение | После кода явно перечислить реальные команды и gaps; при необходимости сделать отдельный docs pass | Реализация готова, но команды запуска/тестов не зафиксированы нигде кроме чата |
| `ER-04` | Failure injection окажется неудобно тестировать через выбранный abstraction level | Риск неполного покрытия `REQ-04`/`FM-04` | Сразу проектировать write path через testable service boundary/result object | В tests приходится мокать controller internals вместо owner-layer failure |
| `ER-05` | Внутренний bootstrap smoke check будет ошибочно принят за доказательство `CHK-01..03` | Можно преждевременно считать feature верифицированной | Явно разделить bootstrap readiness checkpoint и canonical feature verification | Появляется temptation закрыть verify сразу после `STEP-01` |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `DEC-01`, `CON-01`, `CON-03`, `OQ-02` | Для первого slice оказывается нужен внешний AI-dependent interpretation, без которого нельзя пройти supported corpus | Остановить реализацию parsing layer и поднять вопрос upstream | Оставить feature в `planned` с актуальным implementation plan без частично верного capture contract |
| `STOP-02` | `AG-02`, `ER-01` | Bootstrap требует доступов/операций, которые нельзя выполнить в текущей среде без отдельного согласования | Не обходить ограничение; запросить approval на конкретный operational шаг | Репозиторий остается documentation-only, без сломанного частичного bootstrap |
| `STOP-03` | `AG-03`, `REQ-01`, `REQ-05` | В ходе реализации выясняется, что нужен новый user-visible API contract или изменение feature scope | Остановить кодовые изменения на последнем согласованном checkpoint и обновить upstream docs | Сохранить согласованный baseline без contract drift |

## Готово для приемки

План считается исчерпанным, когда:

- `STEP-01..05` завершены без активных stop conditions;
- локально пройдены `CHK-01`, `CHK-02`, `CHK-03`;
- в `artifacts/ft-001/verify/chk-01/`, `chk-02/`, `chk-03/` лежат соответствующие verify outputs;
- simplify review завершен и не оставил открытых замечаний, требующих redesign;
- финальная реализация не вышла за `REQ-01..05` и `NS-01..05` из sibling `feature.md`.
