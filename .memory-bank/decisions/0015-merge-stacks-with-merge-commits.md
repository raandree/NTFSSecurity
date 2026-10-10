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
- Applied: 5.0.0-rc2, the PRs #99 to #106 on 2026-10-05; 5.0.0-rc7, the PRs
  #116, #120, #118, and #119 on 2026-10-10.
- Operating rule (2026-10-10): retarget each pull request of the stack to
  `master` (`gh pr edit <n> --base master`) before the one below it is merged,
  and delete a head branch only when no open pull request uses it as its base.
  Deleting a base branch through the GitHub CLI closed #117 without a merge:
  GitHub did not retarget it. The open reports cli/cli#1168 and cli/cli#14223
  show the same events (the first says that the button on the pull request
  page retargets, the second quotes a maintainer who sees a platform issue) and
  report that a closed pull request can't be retargeted or reopened while its
  base is missing (not tried here). #120, a new pull request from the same
  head, replaced #117. Nothing was lost; no content conflicted.
