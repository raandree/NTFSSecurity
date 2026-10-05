---
status: accepted
date: 2026-10-04
last-verified: 2026-10-04
owner: shared
source: maintainer decision after work package 4
---

# Decision 11: CI and the wiki run on GitHub Actions

- Choice: `.github/workflows/ci.yml` replaces AppVeyor. On pull requests and
  pushes to `master`, the `build` job (`windows-2025`) builds the module in
  Release, checks the docs against the build, and runs the Pester tests in
  Windows PowerShell 5.1 and PowerShell 7. The `wiki` job converts `Docs`
  with `.github/scripts/Export-WikiContent.ps1` and publishes the wiki from
  `master` with the built-in token; on pull requests it lists the pages that
  would change. `appveyor.yml` is removed.
- Rationale: The maintainer wants a browsable wiki without a second, hand-
  written copy of the docs (the 2018 wiki went stale), and one CI platform
  instead of two. Public repositories get Windows runners for free, and the
  checks appear on the pull request without a third-party service.
- Consequences: `Docs` stays the only source (Decision 9); the wiki is a
  generated mirror, and edits made in the wiki are overwritten. Only the
  `publish-wiki` job, which runs for `master` alone, has `contents: write`;
  the `wiki` job that previews pull requests, including Dependabot's, is
  read-only (2026-10-04). Actions are pinned by commit SHA. Test
  results appear in the job summary and as the `test-results` artifact.
- Rejected: a hand-maintained wiki next to `Docs`, publishing the wiki by
  hand at release time, and keeping AppVeyor for build and tests.
