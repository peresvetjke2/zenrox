---
title: "PRD-002: Conversational Routing For Core Assistant Actions"
doc_kind: prd
doc_function: canonical
purpose: "Фиксирует следующую продуктовую инициативу zenrox: убрать зависимость от жестких команд и дать пользователю естественный conversational entrypoint для базовых task-действий."
derived_from:
  - ../domain/problem.md
  - ../domain/frontend.md
  - ./PRD-001-first-capture-and-retrieval-loop.md
status: active
audience: humans_and_agents
must_not_define:
  - implementation_sequence
  - architecture_decision
  - feature_level_verify_contract
---

# PRD-002: Conversational Routing For Core Assistant Actions

## Problem

`PRD-001` доказал, что `zenrox` уже может сохранить одну личную задачу, вернуть список открытых задач и принимать сообщения через phone-friendly Telegram channel. Но этот контур пока слишком хрупок на уровне пользовательского опыта: чтобы получить нужное действие, пользователь должен помнить конкретные "заклинания" и обходные формулировки вместо того, чтобы писать естественно.

Такое состояние конфликтует с базовым product context `zenrox`, где primary interaction mode — свободная реплика, а assistant должен понимать намерение пользователя и направлять его в подходящий сценарий. Пока conversational entrypoint не умеет надежно различать несколько базовых intents и не дает удобный способ сослаться на конкретную задачу в follow-up диалоге, дальнейшее развитие task lifecycle, time-aware retrieval и более сложных personal-memory сценариев будет преждевременным: новые capability будут существовать, но пользоваться ими останется неудобно и непредсказуемо.

Следующая инициатива должна закрыть именно этот UX и capability gap. Ее задача — не "научить бота понимать все", а ввести первый надежный intent-routing слой для ограниченного набора core assistant actions, чтобы пользователь мог обращаться к системе естественным языком, а система либо выполняла правильный flow, либо честно просила уточнение, либо явно отказывала без выдумывания смысла.

Этот PRD сознательно выбирает single-intent routing как первый product-safe шаг к более широким workflows из `domain/problem.md`. Он не отменяет более амбициозный vision свободного multi-intent understanding, а задает узкий и проверяемый capability-layer, на который потом можно безопасно наращивать более сложное понимание пользовательских реплик.

## Users And Jobs

| User / Segment | Job To Be Done | Current Pain |
| --- | --- | --- |
| `primary-user` | Написать естественную реплику и получить нужное базовое действие без запоминания специальных команд | Текущий UX зависит от knowledge of exact phrases вроде `задачи`, что делает assistant менее естественным и менее полезным на ходу |
| `primary-user` | Быстро спросить, что у него открыто, другими словами, а не одной фиксированной командой | Retrieval-сценарий хрупок и плохо переносится на реальный разговорный usage |
| `primary-user` | Отметить задачу выполненной, вернуть ее в работу или удалить через тот же диалог | Lifecycle workflows практически недоступны, пока нет надежного routing и удобного способа сослаться на задачу без повторения длинного текста |
| `primary-user` | Увидеть список задач и сослаться на конкретный пункт без повторения длинного текста задачи | При длинных названиях неудобно дословно повторять задачу, а глобальные технические ID плохо подходят для разговорного UX |
| `primary-user` | Понять, когда assistant не уверен в намерении, и быстро дать уточнение | Без explicit ambiguity handling система либо требует заклинания, либо рискует ложной интерпретацией |

## Goals

- `G-01` Убрать зависимость core assistant flows от одной фиксированной команды или единственной допустимой формулировки.
- `G-02` Поддержать первый natural-language routing для ограниченного набора базовых task-intents в том же conversational channel.
- `G-03` Сохранить user trust: при ambiguity или недостаточной уверенности система должна предпочитать clarification или явный отказ, а не рискованное действие.
- `G-04` Сделать базовые task actions реально пригодными для повседневного mobile usage без необходимости помнить продуктовые команды.
- `G-05` Поддержать простой conversational reference-механизм, чтобы пользователь мог ссылаться на задачу по номеру из недавно показанного списка вместо повторения полного текста.

## Non-Goals

- `NG-01` Инициатива не должна неявно превращаться в general-purpose assistant, который понимает произвольные домены и выполняет неограниченный набор действий.
- `NG-02` Multi-intent decomposition одной реплики на несколько независимых действий не входит в первый routing scope.
- `NG-03` `note`, `fact`, entity linking, project hierarchy, subtasks и knowledge-graph scenarios остаются вне этой инициативы.
- `NG-04` Time-aware planning queries вроде `что у меня сегодня?`, reminder delivery и scheduler-driven behavior не входят в этот PRD.
- `NG-05` Инициатива не требует rich UI, отдельного browse screen или нового клиентского приложения поверх существующего conversational channel.
- `NG-06` Инициатива не должна молча менять product contract already-implemented capture-path и retrieval-path там, где routing может просто переиспользовать существующие capability.
- `NG-07` Поддержка voice input, файлов, изображений и других нетекстовых входов не входит в scope этой инициативы.
- `NG-08` Общий поиск по всей personal memory не входит в инициативу.
- `NG-09` Semantic search по `tasks`, `notes`, `facts`, links, project entities и mixed memory objects не входит в scope этого PRD.
- `NG-10` Свободные task-lookup запросы по теме или фрагменту формулировки вроде `я что-то хотел сделать с коровой` не входят в scope этого PRD.
- `NG-11` Свободные knowledge-вопросы вроде `что я говорил про корову месяц назад?` не входят в scope этого PRD.
- `NG-12` Массовые lifecycle-операции вроде `закрой все по корове` не входят в scope первого routing layer.
- `NG-13` Side-effecting action не должна выполняться по слабому или неочевидному semantic match.
- `NG-14` Глобальные технические database IDs не должны становиться primary conversational handle для раннего UX, даже если они доступны системе внутренне.

## Product Scope

Инициатива описывает первый conversational routing layer для базовых task-действий в `zenrox`. Пользователь по-прежнему общается с assistant одной свободной репликой, но теперь система должна различать ограниченный набор поддерживаемых intents, показывать список задач в user-friendly виде и маршрутизировать сообщение в подходящий downstream flow.

### In Scope

- Пользователь может естественной текстовой репликой создать одну задачу, если реплика соответствует supported single-intent capture contract.
- Пользователь может естественной текстовой репликой запросить список открытых задач без привязки к единственной команде `задачи`.
- Пользователь может сослаться на задачу по номеру из непосредственно предшествующего списка или shortlist, который assistant только что показал в том же conversational flow.
- Пользователь может естественной текстовой репликой перевести задачу в `done`, если target task определена однозначно по правилам этой инициативы.
- Пользователь может естественной текстовой репликой вернуть задачу из `done` в `open`, если target task определена однозначно по правилам этой инициативы.
- Пользователь может естественной текстовой репликой удалить задачу, если target task определена однозначно по правилам этой инициативы.
- Если intent неясен, unsupported или target task нельзя определить безопасно, assistant должен перейти в clarification flow или explicit rejection без побочного изменения состояния.
- Conversational routing должен работать в уже существующем primary mobile-friendly channel и не требовать отдельного режима взаимодействия.

### Out Of Scope

- Разбор нескольких независимых намерений из одной реплики с частичным выполнением.
- Date-based retrieval, weekly planning views, priority planning и другие time-aware queries.
- Reminder creation, reminder editing, reminder delivery и все background notification flows.
- Создание и редактирование проектов, подзадач, ссылок между сущностями, заметок и фактов.
- Общий semantic search по всей personal memory и ответы на произвольные knowledge queries.
- Task lookup по частичной, переформулированной или тематической формулировке вне контекста только что показанного списка.
- Browse-like task search interface, отдельный search mode или отдельный history screen.
- Полноценное редактирование текста задачи, due date, суммы или других атрибутов.
- Автоматическая коррекция ambiguous lifecycle command без явного безопасного правила выбора target task.
- Persistent browse-oriented numbering scheme для всех задач пользователя вне контекста конкретного списка.

## UX / Business Rules

- `BR-01` Первый routing scope должен оставаться узким и явно перечислимым: `capture task`, `list open tasks`, `mark task done`, `reopen task`, `delete task`, `clarification / unsupported`.
- `BR-02` Пользователь не должен быть обязан помнить специальную команду `задачи`; retrieval открытых дел не должен зависеть от одной фиксированной команды или одной канонической фразы.
- `BR-03` Routing layer должен переиспользовать существующие capability `PRD-001` и не должен сам по себе менять их product contract; в частности, routing capture-intent не расширяет admission semantics single-intent capture-path автоматически, пока downstream feature явно не меняет этот контракт.
- `BR-04` Если одна реплика может разумно означать несколько intents или несколько target tasks, assistant не должен выполнять side-effecting action до уточнения.
- `BR-05` Для side-effecting lifecycle actions безопасный default — clarification, а не догадка; ложноположительное изменение статуса хуже, чем дополнительный вопрос.
- `BR-05A` Для destructive action `delete task` безопасный default особенно строгий: при любой неуверенности система должна остановиться на clarification, а не выполнять удаление.
- `BR-06` Lifecycle action считается supported только если система может однозначно сопоставить команду с одной существующей задачей по product rules этой инициативы.
- `BR-06A` В рамках этого PRD side-effecting lifecycle action допустим только в двух случаях: пользователь указывает номер элемента из последнего user-visible task list / shortlist, либо пользователь указывает текст задачи, который точно совпадает ровно с одной существующей задачей. Во всех остальных случаях нужен clarification verdict без изменения состояния.
- `BR-06C` Если assistant показывает список или shortlist задач, он может присвоить этим элементам короткие временные порядковые номера внутри данного ответа или ближайшего conversational context, чтобы пользователь мог сказать `закрой задачу 1`, `удали 2` или `верни 3 в работу`.
- `BR-06D` Такие порядковые номера являются context-local reference, а не глобальными идентификаторами задачи: они валидны только в пределах ограниченного недавнего conversational context и не должны masquerade как постоянный task ID.
- `BR-06E` Глобальный database ID может использоваться системой внутренне для надежного target resolution, но не должен быть primary user-facing reference mechanism раннего продукта.
- `BR-07` Clarification flow должен быть коротким и conversational: он объясняет, что именно неясно, и подсказывает, какое уточнение нужно, не сваливая пользователя в form-like interaction.
- `BR-08` Explicit rejection должен ясно отличаться от successful action и не должен создавать видимость, что assistant что-то сохранил, завершил, вернул в работу или удалил.
- `BR-09` Первый routing layer может оставаться single-intent only: если пользователь прислал смешанную реплику вроде "покажи задачи и закрой купить молоко", система может отказать в автоматическом выполнении и попросить разбить запрос.
- `BR-10` Эта инициатива должна усиливать, а не обходить conversational-first UX из `domain/frontend.md`: основной сценарий — свободная реплика в том же диалоге без обязательного перехода в отдельный edit mode.
- `BR-11` Retrieval capability этого PRD ограничен выводом списка open tasks и follow-up ссылками на элементы этого списка; он не должен неявно превращаться в общий memory retrieval surface или в свободный task search по теме.
- `BR-12` После успешного удаления assistant обязан дать явный user-visible отчет, что задача удалена, и не должен оставлять неясность между `done` и `deleted`.

## Success Metrics

| Metric ID | Metric | Baseline | Target | Measurement method |
| --- | --- | --- | --- | --- |
| `MET-01` | Зависимость от product incantations | Сейчас retrieval и будущие lifecycle scenarios завязаны на знание специальных команд и точных формулировок | Для core supported intents пользователь может использовать несколько естественных формулировок без потери результата | Сценарная проверка на корпусе пользовательских реплик с парафразами |
| `MET-02` | Практическая полезность conversational retrieval | Первый retrieval существует, но его discoverability и conversational naturalness ограничены | Пользователь может получить список открытых задач естественным вопросом и без знания слова `задачи` как единственного trigger | Acceptance scenarios на наборе retrieval paraphrases |
| `MET-03` | Практическая полезность list-based reference | При длинных названиях задач пользователю неудобно повторять полный текст, а глобальные ID не подходят для разговорного UX | После вывода списка задач пользователь может сослаться на нужный пункт короткой формулировкой вроде `закрой 1` или `удали задачу 2` в supported context-local scenarios | Сценарная проверка на list-follow-up commands после user-visible task list |
| `MET-04` | Практическая полезность базового task lifecycle | Даже при наличии статусов lifecycle трудно использовать без natural-language routing и удобного target resolution | Пользователь может отметить задачу выполненной, вернуть ее в работу или удалить через свободную реплику в supported unambiguous scenarios, включая list-based references | Сценарная проверка на happy-path lifecycle commands, list-based references и ambiguity cases |
| `MET-05` | Trust при ambiguity | При расширении routing растет риск ложных действий | В ambiguous или unsupported scenarios система не делает побочного изменения состояния и дает явный clarification или rejection verdict | Deterministic negative coverage на ambiguous inputs и stale/missing list-reference cases |

## Risks And Open Questions

- `RISK-01` Инициатива может расползтись в "бот понимает все", если не удерживать narrow intent taxonomy и explicit non-goals.
- `RISK-02` Слишком агрессивный routing ухудшит trust-контракт `zenrox`, если assistant начнет ошибочно завершать задачи или интерпретировать retrieval-вопрос как capture-intent.
- `RISK-03` Если routing rules будут слишком зависеть от transport-specific phrasing, продукт останется brittle и плохо переносимым на другие conversational surfaces.
- `RISK-04` Lifecycle actions блокируются target resolution problem: если context-local reference сломается или окажется неочевидным, follow-up UX снова станет неудобным.
- `RISK-05` Слишком слабый clarification UX уберет "заклинания", но заменит их раздражающей серией уточняющих вопросов, что тоже ухудшит mobile usage.
- `RISK-06` Даже без свободного task lookup scope может расползтись в browse/search subsystem, если context-local numbering попытаются сделать постоянной или глобальной.
- `RISK-07` Context-local numbering может стать confusing, если assistant неочевидно меняет referent списка или если пользователь пытается ссылаться на слишком старый список.
- `OQ-01` Достаточно ли conversational clarification внутри того же чата для большинства ambiguous scenarios, или позже понадобится lightweight structured disambiguation поверх текста? На уровне этого PRD ответ не блокирует инициативу, потому что базовый контракт уже допускает текстовое уточнение.

## Downstream Features

| Feature | Why it exists | Status |
| --- | --- | --- |
| `FT-004` | Фиксирует intent taxonomy и routing contract для ограниченного набора core task actions, включая ambiguity handling и explicit unsupported verdicts. | planned |
| `FT-005` | Расширяет retrieval slice так, чтобы запрос списка открытых задач работал по нескольким естественным формулировкам, выводил context-local reference numbers и позволял follow-up targeting без перехода к общему memory search. | planned |
| `FT-006` | Добавляет conversational lifecycle actions `mark task done`, `reopen task` и `delete task` поверх routing и list-based references, с безопасным target resolution, backward compatibility старых trigger-ов и trust contract. | planned |
