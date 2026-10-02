---
schema-version: 1
loading-mode: routed
status: accepted
owner: shared
last-verified: 2026-10-02
source: repository evidence
---

# Memory Bank index

Read this file first. It routes tasks to the smallest relevant set of Memory
Bank files.

## Full-read fallback

Set `loading-mode` to `full` to restore complete-base loading. Also fail open
when this index is missing or invalid, the task is ambiguous, routes conflict,
a listed file is missing, or a critical fact cannot be found. Full mode also
reads every existing `decisions/*.md` record.

## Routing table

Combine routes when a task spans topics. For durable repository writes, also
read `activeContext.md` before editing.

| Route | Task signals | Read |
|---|---|---|
| `general` | General Q&A with no project decision | Index only |
| `continuation` | Resume, current focus, next step | `activeContext.md`, `progress.md` |
| `scope` | Purpose, scope, requirements, Acceptance criteria | `projectbrief.md` |
| `product` | Users, problem, workflow, experience goal | `productContext.md` |
| `implementation` | Code, configuration, build, test, dependency, deployment | `techContext.md`, `activeContext.md` |
| `architecture` | Design, pattern, decision, migration, integration | `systemPatterns.md`, relevant `decisions/*.md` |
| `status` | Progress, recent change, open work | `progress.md`, `activeContext.md` |
| `language` | Canonical terms in authored artifacts | `glossary.md` |
| `interaction-history` | Session analysis, prompt trends, Memory Bank evals | `promptHistory.md`, `progress.md` |
| `role` | Active Custom agent domain workflow | Only that agent's declared role files |

## Authority order

1. The user's current request controls task constraints.
2. Repository source, configuration, tests, and evidence control facts.
3. Accepted decision records control durable architectural choices.
4. Core Memory Bank files control only their assigned topic.
5. Historical logs never override current source.
