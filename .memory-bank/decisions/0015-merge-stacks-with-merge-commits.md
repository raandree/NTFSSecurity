---
status: accepted
date: 2026-10-05
last-verified: 2026-10-05
owner: shared
source: maintainer decision of 2026-10-05
---

# Decision 15: Merge stacked pull requests in order with merge commits

- Choice: A stack of pull requests whose branches build on each other is
  merged into `master` in order, each with **Create a merge commit**. The
  merges wait for the CI run of the last pull request, which contains every
  commit of the stack; an earlier one may fail tests that a later one fixes.
- Rationale: Squash and rebase merges rewrite the commits, so every later
  pull request would conflict, and the commit IDs in the descriptions and
  the changelog would no longer exist on `master`. A merge commit keeps
  them, and each merge leaves `master` at the tree its pull request tested.
- Applied: 5.0.0-rc2, the PRs #99 to #106 on 2026-10-05.
