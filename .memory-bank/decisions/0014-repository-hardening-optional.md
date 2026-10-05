---
status: accepted
date: 2026-10-05
last-verified: 2026-10-05
owner: shared
source: maintainer decision of 2026-10-05
---

# Decision 14: Repository hardening is optional

- Choice: The repository settings proposed on 2026-10-04 stay optional:
  required reviewers and a tag-only deployment policy for the environment
  `powershell-gallery`, a ruleset for `master` that requires a pull request
  and the **Build and test** check, and a rotation of `PSGALLERY_API_KEY`.
  None of them is a gate for a merge or a release.
- Rationale: The maintainer is the only developer. The PRs #99 to #106 of
  5.0.0-rc2 were merged on 2026-10-05 without these settings.
- Consequences: `master` accepts a merge while checks fail, and the Release
  job publishes without an approval. The safeguards are the CI run of the
  last pull request of a stack before its merges, the CI run on `master`
  before the tag, and the checks of the Release job (Decision 12). Agents
  don't press for the settings; the proposal stays with the maintainer,
  outside the repository.
