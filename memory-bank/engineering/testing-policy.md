---
title: Testing Policy
doc_kind: engineering
doc_function: canonical
purpose: Описывает testing policy репозитория: обязательность test case design, требования к automated regression coverage и допустимые manual-only gaps.
derived_from:
  - ../dna/governance.md
  - ../flows/feature-flow.md
status: active
canonical_for:
  - repository_testing_policy
  - feature_test_case_inventory_rules
  - automated_test_requirements
  - sufficient_test_coverage_definition
  - manual_only_verification_exceptions
  - simplify_review_discipline
  - verification_context_separation
must_not_define:
  - feature_acceptance_criteria
  - feature_scope
audience: humans_and_agents
---

# Testing Policy

## Project Adaptation

Проект находится на ранней стадии: product contract уже формируется, но точный runtime stack, test framework и CI pipeline еще не зафиксированы. До выбора стека этот документ задает policy-level правила, а не конкретный набор команд.

На текущем этапе уже зафиксированы следующие project-specific ожидания:

- deterministic behavior в parsing, status transitions, retrieval filters и reminder scheduling должен получать automated coverage, как только появляется реалистичный test harness;
- сценарии, завязанные на live AI provider, Telegram delivery и реальное время доставки reminders, временно могут требовать manual verification, если automation еще не поднята;
- отсутствие готовой CI не отменяет требования проектировать verify-path вместе с feature, если поведение уже достаточно стабильно для тестирования.

## Core Rules

- Любое изменение поведения, которое можно проверить детерминированно, обязано получить automated regression coverage.
- Любой новый или измененный contract обязан получить contract-level automated verification.
- Любой bugfix обязан добавить regression test на воспроизводимый сценарий.
- Required automated tests считаются закрывающими риск только если они проходят локально и, когда CI уже существует, не противоречат CI verify.
- Manual-only verify допустим только как явное исключение и не заменяет automated coverage там, где automation реалистична.

## Ownership Split

- Canonical test cases delivery-единицы задаются в `feature.md` через `SC-*`, feature-specific `NEG-*`, `CHK-*` и `EVID-*`.
- `implementation-plan.md` владеет только стратегией исполнения: какие test surfaces будут добавлены или обновлены, какие gaps временно остаются manual-only и почему.

## Feature Flow Expectations

Canonical lifecycle gates живут в [../flows/feature-flow.md](../flows/feature-flow.md):

- к `Design Ready` `feature.md` уже фиксирует test case inventory;
- к `Plan Ready` `implementation-plan.md` содержит `Test Strategy` с planned automated coverage и manual-only gaps;
- к `Done` required tests добавлены, доступные локальные команды зелёные и, когда CI уже существует, CI не противоречит локальному verify.

## Что Считается Sufficient Coverage

- Покрыт основной changed behavior и ближайший regression path.
- Покрыты новые или измененные contracts, события, schema или integration boundaries.
- Покрыты критичные failure modes из `FM-*`, bug history или acceptance risks.
- Покрыты feature-specific negative/edge scenarios, если они меняют verdict.
- Процент line coverage сам по себе недостаточен: нужен scenario- и contract-level coverage.

## Когда Manual-Only Допустим

- Сценарий зависит от live infra, внешних систем, hardware, недетерминированной среды или human оценки UI.
- Для каждого manual-only gap: причина, ручная процедура, owner follow-up.
- Если manual-only gap оставляет без regression protection критичный путь, feature не считается завершённой.

## Simplify Review

Отдельный проход верификации после функционального тестирования. Цель: убедиться, что реализация минимально сложна.

- Выполняется после прохождения tests, но до closure gate.
- Паттерны: premature abstractions, глубокая вложенность, дублирование логики, dead code, overengineering.
- Три похожие строки лучше premature abstraction. Абстракция оправдана только когда она реально уменьшает риск или повтор.

## Verification Context Separation

Разные этапы верификации — отдельные проходы:

1. **Функциональная верификация** — tests проходят, acceptance scenarios покрыты
2. **Simplify review** — код минимально сложен
3. **Acceptance test** — end-to-end по `SC-*`

Для small features допустимо в одной сессии, но simplify review не пропускается.

## Project-Specific Conventions

Минимальные downstream-specific правила для `zenrox` на текущем этапе:

- изменения в rule-like поведении должны по возможности тестироваться без live AI и без реального reminder delivery.
- если feature добавляет или меняет parsing contract, task status lifecycle, reminder semantics или retrieval filtering, автор изменения обязан явно указать, какая часть verify остается automated, а какая временно manual-only.
- если deterministic automated coverage пока невозможна из-за отсутствия выбранного test harness, это должно быть записано как временный gap, а не замалчиваться.
- manual verification для AI-assisted flows должна опираться на конкретные примеры пользовательских реплик, а не на абстрактную формулировку "проверено вручную".
- перед handoff агент обязан честно перечислить, какие проверки реально были запущены и какие не были доступны в текущем состоянии проекта.

## Checklist For Template Adoption

- [ ] указаны реальные local test commands после выбора стека
- [ ] перечислены обязательные CI suites после появления CI pipeline
- [ ] задокументирован deterministic test data pattern после выбора test harness
- [x] описаны manual-only exceptions раннего этапа
- [x] policy не противоречит [../flows/feature-flow.md](../flows/feature-flow.md)
