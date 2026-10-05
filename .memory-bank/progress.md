---
status: current
last-verified: 2026-10-05
owner: active-agent
source: repository evidence
---

# Progress

## Current status

5.0.0-rc2 is ready on eight stacked local branches from the overnight run of
2026-10-04/05; none is pushed. Each is a PR against `master`, merged in
this order with merge commits: `ai/maintenance`, `ai/defects-a`,
`ai/defects-b`, `ai/defects-c`, `ai/defects-d`, `ai/decisions-e`,
`ai/issue-fixes`, `ai/release-5.0.0-rc2`. The tag `5.0.0-rc2` on the last
merge commit then publishes it through CI (Decision 12). `master`
(`e0f5366`) carries 5.0.0-rc1, published on 2026-10-04; the stable Gallery
version is still 4.2.6.

## Recent milestones

- 2026-10-02 to 2026-10-04: #91 to #97 aligned the docs with the code,
  shipped the help file, kept the docs on GitHub, set version 5.0.0, moved
  CI and a wiki generated from `Docs` to GitHub Actions, and completed the
  version history (Decisions 6 to 11).
- 2026-10-04: #98 (`e0f5366`) added releases on a version tag through CI
  (Decision 12). The tag `5.0.0-rc1` published to the Gallery and created
  the GitHub prerelease; the installed module passed the full suite.
- 2026-10-05, overnight run (local branches): the 24 code defects of work
  package 5 fixed with regression tests, plus what the reviews found: a
  failed retry after taking ownership left the owner changed, and
  `-PassThru` wrote objects after a failed change or under `-WhatIf`.
  Maintainer decisions D2 to D5 (Decision 13), the issues #3, #4, #74, #86,
  and #88 fixed, the 37 open issues triaged, `Docs/FAQ.md`, Dependabot for
  the actions, and the prerelease label `rc2`. One security review per PR;
  every Major finding fixed. Tests at the top branch: Windows PowerShell
  405 passed, 26 skipped; PowerShell 7 376 passed, 55 skipped (431).

## Stable capabilities

- 36 cmdlets: access (7), audit (5), inheritance (6), owner and security
  descriptor (4), privileges (3), long-path items (6), links, hash, and
  disk space (5).
- Works in Windows PowerShell 5.1 and PowerShell 7. In PowerShell 7,
  `Get-FileHash2` lacks `RIPEMD160` and `MACTripleDES`, which .NET lacks
  (on `master` it still fails there for every algorithm).
- Pester tests in `Tests\` run in `$env:TEMP` sandboxes through
  `Tests\TestHelpers.psm1`; tests that need privileges skip without them
  and run in CI, whose runners are elevated.

## Open work

1. The maintainer pushes the eight branches, opens the PRs, merges them in
   order, and tags `5.0.0-rc2` once CI on `master` is green; then tests
   rc2.
2. Release 5.0.0 through CI (Decision 12) after the tests: remove the
   label, date `[Unreleased]` as `[5.0.0]`, tag `5.0.0` (steps in
   `Docs/Contributing/05-Releasing.md`; CI warns when the changelog date
   isn't the release day).
3. Repository settings, proposed on 2026-10-04 (not yet agreed): the
   `powershell-gallery` environment has no protection rules and no
   deployment policy, so a workflow on any branch can use
   `PSGALLERY_API_KEY` (`nyanhp` also has write access); `master` has no
   protection or ruleset; head branches aren't deleted on merge; the
   remote branches `fix/#34` and `test/transfer` aren't merged.
4. Open bugs from the triage: #5 (`Get-ChildItem2 -Attributes` matches all
   attributes, `Get-ChildItem` any; needs a decision), #17 (an ACE with
   `GenericAll` can't be removed), #34 and #67 (the write includes owner
   and group; `fix/#34` swallows every error), #41 (a drive root reads the
   device object), #82 (a `Size` member of other type data blocks the
   import), #90 (a trailing space in a folder name). Enhancements: #22,
   #49, #68, #77, #87.
5. Minor review findings that the PRs list but don't fix, for example
   `Copy-Item2 -WhatIf` reporting a destination conflict as an error, and
   relative path forms that the `*-Item2` cmdlets resolve themselves.
6. Optional for the maintainer: delete the AppVeyor project and revoke its
   GitHub authorization, restrict wiki editing to collaborators, and ask
   `Sup3rlativ3` to delete the Read the Docs project.
