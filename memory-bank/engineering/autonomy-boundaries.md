---
title: Autonomy Boundaries
doc_kind: engineering
doc_function: canonical
purpose: Границы автономии агента: что можно делать без подтверждения, где нужна супервизия, когда эскалировать.
derived_from:
  - ../dna/governance.md
canonical_for:
  - agent_autonomy_rules
  - escalation_triggers
  - supervision_checkpoints
status: active
audience: humans_and_agents
---

# Autonomy Boundaries

## Автопилот — делай без подтверждения

- Редактировать код в рамках задачи
- Запускать локальные тесты и линтеры
- Создавать ветки и worktrees
- Читать логи, метрики и error tracker
- Создавать и обновлять внутреннюю документацию
- Создавать и обновлять документацию в memory-bank
- Адаптировать `domain`, `use-cases` и другие upstream-документы memory-bank, если продуктовые правила уже явно проговорены

## Супервизия — делай, но покажи на контрольной точке

- Архитектурные решения, новые сервисы и изменение контрактов — покажи план до начала
- Изменение схемы БД и data migration — покажи миграцию до запуска
- Удаление кода или файлов — покажи что удаляешь и почему
- PR в default branch — покажи diff и результаты тестов
- Изменение конфигурации, маршрутизации или deployment contract — покажи изменения
- Декомпозиция задачи на sub-issues — покажи разбиение
- Подключение или изменение AI provider, Telegram integration, reminder delivery channel или scheduler/runtime support — покажи изменения и verify plan
- Изменение task model, reminder semantics, link model или retrieval contract — покажи обновленный domain/use-case слой до или вместе с кодом

## Эскалация — остановись и спроси

- Неясные или противоречивые бизнес-требования
- Выбор между несколькими равноценными подходами с разными trade-offs
- Любые действия в production или against live data
- Отправка сообщений пользователям или внешним контрагентам
- Изменение платёжных, security, auth или compliance-sensitive интеграций
- Конфликтующие паттерны в кодовой базе — не угадывай, спроси какой правильный
- Задача выходит за scope issue — не расширяй молча
- Неопределенность в том, что считать source of truth для задач, reminders, links или conversational context
- Неясность в правилах доставки user-visible notifications, если изменение может привести к пропущенным или лишним напоминаниям

## Правило эскалации

Если замечания или ошибки не уменьшаются после 2-3 итераций, проблема может быть не в коде, а в upstream-требованиях, плане или ограничениях среды. В этом случае агент останавливает цикл и предлагает вернуться на предыдущий этап.

## Project Notes

Для `zenrox` действует дополнительное правило ранней стадии:

- если продуктовое решение еще не закреплено в `domain` или `use-cases`, агент сначала старается поднять это решение на documentation layer, а не маскировать неопределенность кодом;
- если изменение затрагивает внешний AI, live reminder delivery или Telegram-facing behavior, результаты manual verification и ограничения среды должны быть озвучены явно;
- если у проекта еще нет устоявшегося test/runtime stack, агент не придумывает фиктивные команды, CI jobs или deployment stages.
