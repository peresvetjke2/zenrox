---
title: "FT-001: Single-task Text Capture"
doc_kind: feature
doc_function: canonical
purpose: "Расширенный canonical feature-документ design-ready уровня для первого capture slice: сохранить одну личную задачу из одной текстовой реплики либо явно отказать без ложного подтверждения."
derived_from:
  - ../../domain/problem.md
  - ../../prd/PRD-001-first-capture-and-retrieval-loop.md
  - ../../use-cases/UC-006-single-task-text-capture.md
status: active
delivery_status: done
audience: humans_and_agents
must_not_define:
  - implementation_sequence
---

# FT-001: Single-task Text Capture

## What

### Problem

`PRD-001` задает первый полезный task loop для `zenrox`, но сам по себе не определяет delivery-scoped contract для capture-path. Для первого MVP нужен узкий и предсказуемый slice, в котором пользователь может отправить одну короткую текстовую реплику и получить либо одну сохраненную `open`-задачу, либо явный отказ с объяснением причины.

Эта фича сознательно не пытается решать general parsing problem. Ее задача — зафиксировать минимальное admission rule для первого capture-flow так, чтобы `zenrox` не создавал молчаливые побочные записи, не подтверждал неуспешное сохранение и не размывал первый MVP до multi-intent или mixed-intent интерпретации.

### Outcome

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Надежность первого capture-path | Без явного admission rule пользователь не может предсказать, когда реплика сохранится как задача, а когда система ошибочно угадает intent | В supported input-сценарии одна текстовая реплика сохраняется как одна `open`-задача с коротким подтверждением; в unsupported сценарии пользователь получает явный отказ с объяснением причины | Acceptance scenarios и deterministic checks на фиксированном наборе supported / unsupported реплик |
| `MET-02` | Trust-контракт подтверждения | Без явного правила подтверждение может не совпадать с фактическим сохранением | Сообщение о сохранении появляется только после фактического успешного сохранения задачи; при отказе или сбое пользователь получает несомненно неуспешный результат | Scenario-based verification на happy path и failure path |

### Scope

- `REQ-01` Пользователь может отправить одну короткую текстовую реплику, которая выражает одно явное действие, и система сохраняет ее как одну личную задачу в состоянии `open`.
- `REQ-02` После успешного сохранения система возвращает короткое user-visible подтверждение, что задача принята в систему.
- `REQ-03` Если реплика не проходит admission rule первого MVP, система не выполняет автосохранение и дает user-visible обратную связь, что именно помешало сохранить задачу автоматически и какое уточнение или переформулировка требуются.
- `REQ-04` Если сохранение задачи не завершилось успешно, система не выдает ложное подтверждение сохранения и явно сообщает о неуспешном результате.
- `REQ-05` Фича задает минимальный admission parsing contract для capture-path: supported input ограничен одной текстовой репликой с одним явным task-intent без конкурирующих действий или альтернатив.

### Non-Scope

- `NS-01` Разбор нескольких независимых задач из одной пользовательской реплики.
- `NS-02` Голосовой ввод, файлы, изображения и другие нетекстовые входы.
- `NS-03` Reminder-intent, note-intent, retrieval questions и любые mixed-intent сценарии как поддерживаемые capture-path входы первого MVP.
- `NS-04` Глубокое извлечение дополнительных атрибутов, сложная нормализация текста и расширение parsing-а beyond admission rule.
- `NS-05` Пользовательские команды изменения статуса задачи, включая перевод в `done`.

### Constraints / Assumptions

- `ASM-01` На текущем этапе проект не зафиксировал конкретный runtime stack, AI provider contract и test harness; feature contract должен оставаться валидным независимо от выбранной реализации.
- `CON-01` Admission rule первого MVP intentionally conservative: автосохранение допустимо только для реплики, которая читается как одно явное действие и не содержит второго независимого действия, альтернативы или другого primary intent.
- `CON-02` Supported input ограничен текстовым single-message flow; voice-first, batch capture и background processing не допускаются как обязательные части этой delivery-единицы.
- `CON-03` User-visible trust важнее recall parsing-а: в спорных случаях фича обязана отказаться от автосохранения, а не пытаться извлечь задачу ценой ложноположительного результата.
- `DEC-01` Точная внутренняя техника интерпретации входа не выбрана и не является частью этого feature contract, пока она соблюдает `CON-01`..`CON-03` и downstream verify.
- `RJ-01` Unsupported-input rejection обязан явно сообщать, что автосохранение не выполнено, кратко называть причину отказа и подсказывать, что нужно переформулировать реплику как одно явное действие.

### Invariants

- `INV-01` Одна входная текстовая реплика может привести максимум к одной новой задаче; ambiguous или unsupported вход не может порождать частичное автосохранение.
- `INV-02` Success-like подтверждение запрещено до фактического успешного завершения write-path.

## How

### Solution

Фича вводит узкий capture admission layer перед сохранением задачи. Система принимает только те текстовые реплики, которые можно безопасно интерпретировать как одну личную задачу, и во всех остальных случаях возвращает explanatory rejection вместо рискованного автосохранения. Подтверждение о сохранении допустимо только после фактического успешного завершения write-path и не может появляться на speculative этапе.

### Change Surface

| Surface | Type | Why it changes |
| --- | --- | --- |
| `conversational capture entrypoint` | code | Здесь применяется admission rule и формируется user-visible ответ capture-path |
| `task write path / persistence boundary` | code | Здесь должна соблюдаться связь между успешным сохранением и подтверждением пользователю |
| `task entity / minimal status model` | code / data | Фича опирается на возможность создать задачу в состоянии `open` |
| `automated / manual verify artifacts for capture-path` | test / doc | Нужны deterministic сценарии supported и unsupported input для regression protection |

### Flow

1. Пользователь отправляет одну текстовую реплику в основной conversational интерфейс.
2. Capture-path определяет, можно ли интерпретировать реплику как один supported task-intent по admission rule первого MVP.
3. Если реплика supported, система сохраняет одну задачу в состоянии `open`.
4. Если сохранение успешно завершилось, система возвращает короткое подтверждение сохранения.
5. Если реплика unsupported или сохранение неуспешно, система не подтверждает сохранение и возвращает явную обратную связь о причине отказа или сбоя.

### Contracts

| Contract ID | Input / Output | Producer / Consumer | Notes |
| --- | --- | --- | --- |
| `CTR-01` | `text message -> single open task or explicit rejection` | user -> capture-path | Один входной текст может привести максимум к одной сохраненной задаче |
| `CTR-02` | `successful save -> success confirmation` | write path -> user-facing response | Подтверждение допустимо только после фактического успешного сохранения |
| `CTR-03` | `unsupported or failed capture -> explanatory non-success response` | capture-path / write path -> user-facing response | Ответ должен объяснять, что именно помешало автосохранению или почему сохранение не завершилось; для unsupported-input действует `RJ-01` |

### Failure Modes

- `FM-01` Реплика содержит два и более независимых действия, но система ошибочно сохраняет только одно из них как будто ambiguity не было.
- `FM-02` Реплика содержит альтернативу или ветвление, но система делает скрытый выбор и сохраняет задачу без явного решения пользователя.
- `FM-03` Реплика выражает не task-intent, а вопрос, заметку, reminder или mixed-intent, но система ошибочно записывает ее как задачу.
- `FM-04` Сохранение не завершилось успешно, но пользователь получает сообщение, похожее на подтверждение сохранения.
- `FM-05` Система отказывает в автосохранении, но не объясняет причину настолько, чтобы пользователь понял, какое уточнение требуется.

## Verify

`Verify` задает canonical test case inventory для первого capture slice: positive path для supported single-task input и negative coverage для ambiguous, multi-intent, non-task и failed-save случаев.

### Exit Criteria

- `EC-01` Supported single-task text input сохраняется как одна `open`-задача и сопровождается коротким подтверждением после успешного сохранения.
- `EC-02` Unsupported input не приводит к автосохранению и сопровождается явной explanatory feedback о причине отказа, отсутствии автосохранения и требуемой переформулировке.
- `EC-03` Неуспешный write-path не маскируется под успешное сохранение.

### Traceability matrix

| Requirement ID | Design refs | Acceptance refs | Checks | Evidence IDs |
| --- | --- | --- | --- | --- |
| `REQ-01` | `CON-01`, `CON-02`, `CTR-01`, `INV-01` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-02` | `CON-03`, `CTR-02`, `INV-02` | `EC-01`, `SC-01` | `CHK-01` | `EVID-01` |
| `REQ-03` | `CON-01`, `CON-03`, `RJ-01`, `CTR-03`, `FM-01`, `FM-02`, `FM-03`, `FM-05`, `INV-01` | `EC-02`, `SC-02`, `NEG-01`, `NEG-02`, `NEG-03` | `CHK-02` | `EVID-02` |
| `REQ-04` | `CON-03`, `CTR-02`, `CTR-03`, `FM-04`, `INV-02` | `EC-03`, `SC-03`, `NEG-04` | `CHK-03` | `EVID-03` |
| `REQ-05` | `CON-01`, `CON-02`, `DEC-01`, `INV-01` | `EC-01`, `EC-02`, `SC-01`, `SC-02`, `NEG-01`, `NEG-02`, `NEG-03` | `CHK-01`, `CHK-02` | `EVID-01`, `EVID-02` |

### Acceptance Scenarios

- `SC-01` Пользователь отправляет supported текстовую реплику с одним явным действием, система сохраняет ровно одну `open`-задачу и только после успешного сохранения возвращает короткое подтверждение.
- `SC-02` Пользователь отправляет unsupported текстовую реплику, которая не проходит admission rule, и система не создает задачу, а возвращает явное объяснение причины и нужного уточнения или переформулировки.
- `SC-03` Пользователь отправляет реплику, которая проходит admission rule, но write-path завершается неуспешно; система не подтверждает сохранение, не оставляет видимость успешно созданной задачи и возвращает явно неуспешный результат.

### Checks

Verify должен быть исполнимым.

| Check ID | Covers | How to check | Expected result | Evidence path |
| --- | --- | --- | --- | --- |
| `CHK-01` | `EC-01`, `SC-01` | Прогнать deterministic supported-input сценарий на фиксированном корпусе реплик вида `купить молоко`, `позвонить маме`; проверить persisted result и user-visible response | Для каждой supported реплики создается ровно одна `open`-задача и появляется короткое подтверждение только после успешного сохранения | `artifacts/ft-001/verify/chk-01/` |
| `CHK-02` | `EC-02`, `SC-02`, `NEG-01`, `NEG-02`, `NEG-03` | Прогнать deterministic unsupported-input сценарии на фиксированном корпусе ambiguity / multi-intent / non-task реплик; проверить отсутствие новой задачи и наличие explanatory rejection | Для каждой unsupported реплики новая задача не создается, ответ явно говорит, что автосохранение не выполнено, объясняет причину отказа и указывает, какое уточнение или переформулировка нужны | `artifacts/ft-001/verify/chk-02/` |
| `CHK-03` | `EC-03`, `SC-03`, `NEG-04` | Детерминированно инжектировать failed-save path на входе, который проходит admission rule, и проверить persisted result и user-visible response | При write failure новая задача не фиксируется как успешно сохраненная, success-like подтверждение отсутствует, пользователь получает явно неуспешный результат | `artifacts/ft-001/verify/chk-03/` |

### Test matrix

| Check ID | Evidence IDs | Evidence path |
| --- | --- | --- |
| `CHK-01` | `EVID-01` | `artifacts/ft-001/verify/chk-01/` |
| `CHK-02` | `EVID-02` | `artifacts/ft-001/verify/chk-02/` |
| `CHK-03` | `EVID-03` | `artifacts/ft-001/verify/chk-03/` |

### Evidence

- `EVID-01` Артефакт успешного supported-input capture, подтверждающий создание ровно одной `open`-задачи и success confirmation.
- `EVID-02` Артефакт unsupported-input rejection, подтверждающий отсутствие автосохранения и наличие explanatory feedback.
- `EVID-03` Артефакт failed-save сценария, подтверждающий отсутствие ложного подтверждения и отсутствие успешно зафиксированного сохранения.

### Evidence contract

| Evidence ID | Artifact | Producer | Path contract | Reused by checks |
| --- | --- | --- | --- | --- |
| `EVID-01` | Лог, transcript или structured verify output для supported capture | verify-runner / human | `artifacts/ft-001/verify/chk-01/` | `CHK-01` |
| `EVID-02` | Лог, transcript или structured verify output для unsupported rejection | verify-runner / human | `artifacts/ft-001/verify/chk-02/` | `CHK-02` |
| `EVID-03` | Лог, transcript или structured verify output для failed-save path | verify-runner / human | `artifacts/ft-001/verify/chk-03/` | `CHK-03` |

### Negative Scenarios

- `NEG-01` Реплика содержит два независимых действия вроде `купить молоко и позвонить маме`; система не должна сохранять только первую часть как будто вход был однозначным.
- `NEG-02` Реплика содержит альтернативу вроде `или купить билеты, или поехать на машине`; система не должна делать скрытый выбор и создавать задачу без уточнения.
- `NEG-03` Реплика выражает не task-intent, а вопрос, заметку или reminder вроде `что у меня на завтра?`, `у Маши новый номер`, `напомни завтра купить молоко`; система не должна сохранять это как задачу первого MVP.
- `NEG-04` Реплика проходит admission rule, но write-path завершается неуспешно; система не должна выдавать success-like confirmation.
