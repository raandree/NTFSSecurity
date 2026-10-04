---
status: current
last-verified: 2026-10-02
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Work package 1 (housekeeping) on branch `ai/housekeeping`; the five work
packages and their order are in `progress.md`.

## Evidence

- PR #91 is merged into `master` as `690d8dd` (squash merge). The local
  branch `ai/docs-alignment` had the same tree as `690d8dd` and is deleted;
  GitHub had already deleted the remote branch.
- `.memory-bank/promptHistory.md` is ignored by git (`.gitignore`) and stays
  a local file.
- The changelog policy is Decision 7. The inline Decisions moved to
  `decisions/` records because `systemPatterns.md` was near its 110-line
  budget.
- Read the Docs project `ntfssecurity` still builds the fork
  `Sup3rlativ3/NTFSSecurity`.

## Next step

The maintainer pushes `ai/housekeeping` and opens the PR. After the
go-ahead, start work package 2 (ship the generated help).
