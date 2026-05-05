---
title: "FT-003: Implementation Plan"
doc_kind: feature
doc_function: derived
purpose: "Execution-план реализации FT-003. Фиксирует discovery context, шаги, риски и test strategy без переопределения canonical feature-фактов."
derived_from:
  - feature.md
status: archived
audience: humans_and_agents
must_not_define:
  - ft_003_scope
  - ft_003_architecture
  - ft_003_acceptance_criteria
  - ft_003_blocker_state
---

# План имплементации

## Цель текущего плана

Добавить первый phone-friendly delivery channel поверх существующего capture backend: Telegram webhook принимает текстовое сообщение, вызывает общий capture-path, отправляет reply пользователю и не создает дубликаты задач при retry одного `update_id`.

## Current State / Reference Points

| Path / module | Current role | Why relevant | Reuse / mirror |
| --- | --- | --- | --- |
| `config/routes.rb` | Сейчас содержит только `POST /capture` и health-check | Новый transport-layer вход должен добавляться рядом с существующим API | Повторить минималистичный routing без лишних surfaces |
| `app/controllers/captures_controller.rb` | Тонкий controller, делегирующий всю логику в service object | Telegram controller должен оставаться таким же тонким | Mirror controller -> service pattern |
| `app/services/capture/process_message.rb` | Canonical orchestration для capture verdict | Telegram transport должен переиспользовать этот contract, не дублируя parsing logic | Reuse как owner capture-логики |
| `app/services/capture/task_writer.rb` | Persistence boundary для создания `Task` | Здесь нужно добавить retry-safe idempotent behavior по transport-derived `operation_id` | Расширить без ломки текущего `/capture` path |
| `spec/requests/captures_spec.rb` | Current deterministic request coverage и evidence pattern для `FT-001` | Telegram verify должен сохранить такой же contract-level стиль | Mirror request-spec + evidence output |
| `memory-bank/features/FT-001/feature.md` | Canonical owner capture semantics | Нельзя переопределять admission rule или success/failure wording | Reuse `accepted/rejected/failed` verdict vocabulary |
| `memory-bank/ops/config.md` | Ownership-модель конфигурации | Новый Telegram env contract нужно зафиксировать здесь | Дополнить concrete naming |

## Test Strategy

| Test surface | Canonical refs | Existing coverage | Planned automated coverage | Required local suites / commands | Required CI suites / jobs | Manual-only gap / justification | Manual-only approval ref |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `POST /telegram/webhook` happy path | `REQ-01`, `REQ-02`, `SC-01`, `CHK-01` | Нет | Request spec для supported text update и accepted reply | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| webhook retry / idempotency | `REQ-03`, `SC-02`, `CHK-02` | Нет | Request spec с повторной доставкой того же `update_id` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| secret / chat guards and non-text behavior | `REQ-04`, `REQ-05`, `NEG-01`, `NEG-02`, `NEG-03`, `NEG-04`, `CHK-03` | Нет | Request spec для invalid secret, non-text update, non-private chat и disallowed chat id | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `none`, CI еще не адаптирован | none | `none` |
| live Telegram phone smoke | `REQ-05`, `SC-03`, `CHK-04` | Нет | Не автоматизируется локально; выполняется вручную с live bot token и публичным webhook URL через stable non-local deploy или временный `dev+tunnel` path | `none` | `none` | Реальный телефон и live Telegram delivery вне локального deterministic harness | `AG-01` |

## Open Questions / Ambiguities

| Open Question ID | Question | Why unresolved | Blocks | Default action / escalation owner |
| --- | --- | --- | --- | --- |
| `OQ-01` | Какой конкретный public URL будет использоваться для текущего manual smoke-check: stable non-local deploy или временный `dev+tunnel` host | Конкретный hostname зависит от выбранного verify path и появляется только в момент live проверки | `CHK-04` | Не блокирует код; выполнить manual smoke-check на любом допустимом public URL из `memory-bank/ops/development.md` или `memory-bank/ops/stages.md`, owner: human |
| `OQ-02` | Нужно ли жестко требовать `allowed_chat_id` уже в первом rollout | Early-stage single-user setup может захотеть быстрый старт без отдельного onboarding шага | `STEP-03` | По умолчанию сделать allow-list optional и документировать это явно; owner: agent |

## Environment Contract

| Area | Contract | Used by | Failure symptom |
| --- | --- | --- | --- |
| setup | Rails app, PostgreSQL и test harness из `memory-bank/ops/development.md` должны быть доступны локально | `STEP-01`..`STEP-05` | Request specs не запускаются или app не поднимает routes/services |
| test | Canonical verify command на этом этапе: `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `CHK-01`, `CHK-02`, `CHK-03` | Локальный verify нельзя считать завершенным |
| access / network / secrets | Для локальной deterministic реализации live Telegram token не нужен; для `CHK-04` нужны `ZENROX_TELEGRAM_BOT_TOKEN`, optional `ZENROX_TELEGRAM_SECRET_TOKEN` и публичный webhook URL через stable non-local deploy или временный `dev+tunnel` path | `STEP-04`, `CHK-04` | Без live creds/manual infra phone smoke-check остается незавершенным и не должен маскироваться под complete rollout |

## Preconditions

| Precondition ID | Canonical ref | Required state | Used by steps | Blocks start |
| --- | --- | --- | --- | --- |
| `PRE-01` | `FT-001 / ASM-01`, `FT-003 / ASM-02` | Existing capture service и task persistence уже являются canonical owner-слоем для text capture | `STEP-02`, `STEP-03` | yes |
| `PRE-02` | `FT-003 / CON-01`, `FT-003 / CTR-04` | Telegram integration строится как transport layer + platform config, без дублирования business parsing | `STEP-02`, `STEP-03`, `STEP-04` | yes |
| `PRE-03` | `FT-003 / CON-03`, `FT-003 / DEC-01` | Для локального code-complete состояния stable deploy не требуется; для `CHK-04` нужен любой допустимый public webhook URL | `STEP-05` | no |

## Workstreams

| Workstream | Implements | Result | Owner | Dependencies |
| --- | --- | --- | --- | --- |
| `WS-1` | `REQ-01`, `REQ-02`, `REQ-04` | Новый webhook controller/service/config/client path для Telegram transport | agent | `PRE-01`, `PRE-02` |
| `WS-2` | `REQ-03` | Retry-safe idempotency через stable `operation_id` | agent | `PRE-01` |
| `WS-3` | `REQ-05` | Request specs, evidence artifacts и ops docs для env contract | agent | `WS-1`, `WS-2` |

## Approval Gates

| Approval Gate ID | Trigger | Applies to | Why approval is required | Approver / evidence |
| --- | --- | --- | --- | --- |
| `AG-01` | Запуск live webhook registration, сообщение реальному пользователю или проверка через public URL (`dev+tunnel` или production-like) | `CHK-04` | Это внешне-эффективное действие и зависит от live credentials / публичной surface | user approval + manual evidence in `artifacts/ft-003/verify/chk-04/` |

## Порядок работ

| Step ID | Actor | Implements | Goal | Touchpoints | Artifact | Verifies | Evidence IDs | Check command / procedure | Blocked by | Needs approval | Escalate if |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `STEP-01` | agent | `REQ-04` | Зафиксировать upstream docs и env contract для Telegram-канала | `memory-bank/features/FT-003/*`, `memory-bank/prd/PRD-001-first-capture-and-retrieval-loop.md`, `memory-bank/use-cases/UC-006-single-task-text-capture.md`, `memory-bank/ops/*` | Feature package и ops updates | `CHK-03` | `EVID-03` | Doc review + file diff | `PRE-02` | none | Если потребуется менять product semantics beyond capture channel |
| `STEP-02` | agent | `REQ-03` | Сделать write-path idempotent для transport-derived `operation_id` | `app/services/capture/process_message.rb`, `app/services/capture/task_writer.rb` | Retry-safe capture persistence | `CHK-02` | `EVID-02` | Request specs | `PRE-01` | none | Если обнаружится несовместимость с current task contract |
| `STEP-03` | agent | `REQ-01`, `REQ-02`, `REQ-04` | Добавить Telegram webhook controller, interaction service и platform adapters | `config/routes.rb`, `app/controllers/telegram_webhooks_controller.rb`, `app/services/interaction/*`, `app/services/platform/*` | Рабочий webhook path с reply delivery | `CHK-01`, `CHK-03` | `EVID-01`, `EVID-03` | Request specs | `PRE-01`, `PRE-02`, `OQ-02` | none | Если понадобится live network для локального deterministic verify |
| `STEP-04` | agent | `REQ-05` | Добавить deterministic request coverage и evidence artifacts | `spec/requests/telegram_webhooks_spec.rb`, `spec/support/evidence_helper.rb` | Automated regression coverage | `CHK-01`, `CHK-02`, `CHK-03` | `EVID-01`, `EVID-02`, `EVID-03` | `BUNDLE_APP_CONFIG=.bundle mise exec ruby@3.4.8 -- bundle exec rspec` | `WS-1`, `WS-2` | none | Если test harness не проходит локально |
| `STEP-05` | agent | `REQ-05` | Зафиксировать manual-only live smoke gap и провести локальный simplify review | `memory-bank/features/FT-003/feature.md`, финальный handoff | Честный verify state и code-quality pass | `CHK-04` | `EVID-04` | Manual-only note + code review | `PRE-03`, `AG-01` | `AG-01` | Если user потребует live phone proof без любого доступного public webhook URL |

## Parallelizable Work

- `PAR-01` Документирование env contract и проектирование Telegram webhook path можно вести параллельно с анализом idempotency в `TaskWriter`, пока write-surface не редактируется.
- `PAR-02` Request specs стоит писать после стабилизации webhook contract, чтобы не плодить лишние переписывания моков и response semantics.

## Checkpoints

| Checkpoint ID | Refs | Condition | Evidence IDs |
| --- | --- | --- | --- |
| `CP-01` | `STEP-01` | Upstream docs зафиксировали `FT-003` как отдельный delivery package и добавили его в PRD/use-case traceability | `EVID-03` |
| `CP-02` | `STEP-02`, `STEP-03` | Webhook path использует stable `operation_id` и не дублирует capture logic | `EVID-01`, `EVID-02` |
| `CP-03` | `STEP-04`, `STEP-05` | Automated request coverage зелёная, manual live gap явно обозначен | `EVID-01`, `EVID-02`, `EVID-03`, `EVID-04` |

## Execution Risks

| Risk ID | Risk | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- |
| `ER-01` | Telegram reply failure после успешного сохранения задачи | Пользователь не видит результат, а webhook может прийти повторно | Сделать write-path idempotent по `update_id` и позволить безопасный retry reply | Первый failed outbound response |
| `ER-02` | Early-stage auth rule окажется слишком жесткой или слишком мягкой | Канал будет неудобен в setup или небезопасен для случайных входящих updates | Держать `allowed_chat_id` optional, но проверять private chat и secret token, если он задан | Несогласованность между local setup и intended rollout |
| `ER-03` | Live phone proof останется недоступен без deploy surface | Feature нельзя честно закрыть как fully validated | Явно оставить `CHK-04` manual-only и не маскировать этот gap | Отсутствие публичного URL и live token |

## Stop Conditions / Fallback

| Stop ID | Related refs | Trigger | Immediate action | Safe fallback state |
| --- | --- | --- | --- | --- |
| `STOP-01` | `CON-01`, `ASM-02` | Telegram path начинает дублировать capture business logic вместо reuse `FT-001` | Остановить реализацию transport слоя и вернуть логику в existing capture service boundary | Telegram route отсутствует или делегирует только в общий capture service |
| `STOP-02` | `CON-03`, `AG-01` | Для завершения требуют live webhook registration без user approval или без deploy surface | Не выполнять внешние действия, оставить feature как code-complete с manual-only gap | Локально протестированный код и docs без live rollout claim |

## Готово для приемки

План считается исчерпанным, когда Telegram webhook contract реализован, retry-safe write-path покрыт automated tests, ops/docs описывают concrete env contract, а manual live phone gap явно обозначен как отдельный следующий шаг до полного closure.
