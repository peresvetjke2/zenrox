# Agent Entry Point

Отвечай по-русски, если пользователь пишет по-русски.

Не читай .env, .env.local, .envrc и не выводи значения переменных окружения без прямого разрешения пользователя.

## Read Order

При старте задачи читай документы в таком порядке:

1. `memory-bank/README.md`
2. `memory-bank/dna/README.md`
3. `memory-bank/flows/README.md`
4. `memory-bank/engineering/README.md`

Дальше переходи только в релевантные документы:

- product / scope / UX: `memory-bank/domain/*`
- implementation flow: `memory-bank/flows/workflows.md`
- feature package и lifecycle gates: `memory-bank/flows/feature-flow.md`
- testing rules: `memory-bank/engineering/testing-policy.md`
- autonomy / escalation: `memory-bank/engineering/autonomy-boundaries.md`
- coding conventions: `memory-bank/engineering/coding-style.md`
- git / PR expectations: `memory-bank/engineering/git-workflow.md`
- environment / config / release: `memory-bank/ops/*`

## Operating Rules

- Считай `memory-bank` основным источником project knowledge.
- Не дублируй canonical rules из `memory-bank` в новых md-файлах без явной причины.
- Если находишь расхождение между документами, приоритет у upstream/canonical документа по правилам `memory-bank/dna/governance.md`.
- Для маленьких задач используй минимальный workflow из `memory-bank/flows/workflows.md`.
- Если задача меняет контракт, rollout, schema, несколько слоёв системы или требует checkpoints, поднимай её до feature flow из `memory-bank/flows/feature-flow.md`.
- Не создавай downstream-артефакты раньше их upstream-owner: spec/feature -> plan -> execution.
- Любое изменяемое поведение должно иметь deterministic verification по правилам `memory-bank/engineering/testing-policy.md`.
- Если действие попадает в supervision или escalation, следуй `memory-bank/engineering/autonomy-boundaries.md`.

## Documentation Discipline

- Новые документы в `memory-bank` заводи только в правильном разделе и с соблюдением SSoT.
- Каждый новый governed document должен иметь корректный frontmatter и понятный upstream.
- Не создавай orphan docs вне индексируемой структуры.

## Project Adaptation TODO

Этот репозиторий ещё должен заполнить project-specific разделы в:

- `memory-bank/domain/*`
- `memory-bank/engineering/*`
- `memory-bank/ops/*`

Пока эти разделы не адаптированы, агент должен явно помечать допущения о продукте, стеке, тестовых командах, CI и release-процессе.
