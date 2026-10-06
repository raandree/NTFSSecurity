---
status: current
last-verified: 2026-10-05
owner: active-agent
source: repository evidence
---

# Progress

## Current status

5.0.0-rc2 is on the PowerShell Gallery and in the GitHub releases,
published by CI from the tag `5.0.0-rc2` on `master` (`7ddda8d`) on
2026-10-05 (Decision 12). It contains the 24 code defects of work package
5, the issue fixes of the overnight run of 2026-10-04/05, and the CI fix
`629f4e7`. The stable Gallery version is still 4.2.6.

## Recent milestones

- 2026-10-02 to 2026-10-04: #91 to #97 aligned the docs with the code,
  shipped the help file, kept the docs on GitHub, set version 5.0.0, moved
  CI and a wiki generated from `Docs` to GitHub Actions, and completed the
  version history (Decisions 6 to 11).
- 2026-10-04: #98 (`e0f5366`) added releases on a version tag through CI
  (Decision 12). The tag `5.0.0-rc1` published to the Gallery and created
  the GitHub prerelease; the installed module passed the full suite.
- 2026-10-05, overnight run: the 24 code defects of work package 5 and the
  issues #3, #4, #5, #17, #74, #82, #86, and #88 fixed with regression
  tests, plus what one security review per PR found; the 37 open issues
  triaged; `Docs/FAQ.md`, Dependabot for the actions, and the label `rc2`.
  #5 and #82 are breaking changes, like the change of Decision 13.
- 2026-10-05: the first CI runs of the eight PRs found a defect that the
  workstation had skipped, fixed in `629f4e7` (audit inheritance of an item
  without a SACL). The PRs #99 to #106 were merged in order with merge
  commits, CI on `master` passed, and the tag `5.0.0-rc2` published the
  prerelease; GitHub's Actions outage that day cancelled the first two
  attempts of the release run before they started. Repository hardening is
  optional (Decision 14); the merge rule and the maintainer's rule for
  fixes are Decisions 15 and 16.

## Stable capabilities

- 36 cmdlets: access (7), audit (5), inheritance (6), owner and security
  descriptor (4), privileges (3), long-path items (6), links, hash, and
  disk space (5).
- Works in Windows PowerShell 5.1 and PowerShell 7. In PowerShell 7,
  `Get-FileHash2` lacks `RIPEMD160` and `MACTripleDES`, which .NET lacks.
- Pester tests in `Tests\` run in `$env:TEMP` sandboxes through
  `Tests\TestHelpers.psm1`; tests that need privileges skip without them
  and run in CI, whose runners are elevated.

## Open work

1. Test 5.0.0-rc2, then release 5.0.0 through CI (Decision 12): remove the
   label, date `[Unreleased]` as `[5.0.0]`, add `5.0.0-rc2` to
   `$publishedVersions` in `Tests/Repository.Tests.ps1`, and tag `5.0.0`
   (steps in `Docs/Contributing/05-Releasing.md`).
2. Issues: the open issues got their replies on 2026-10-05. Follow-up
   issues for the open Minor review findings: #107 (relative path forms),
   #108 (`Copy-Item2` and `Move-Item2`), #109 (error messages), #110
   (tests), and #111 (small items); #68 tracks `-WhatIf` and `-Confirm` for
   every cmdlet that changes security, and #34 the copied inherited
   entries. The labels follow Decision 17; #16, #21, #45, #67, and #89
   wait for their reporters (Needs Info).
3. 5.0.0-rc3, if a file server that refuses to assign the owner is
   available for a test: #34 and #67. Every section of the security
   descriptor is read and written, so the owner and group are written with
   each change, and in an elevated session inherited entries are copied as
   explicit ones; `fix/#34` swallows every error and needs a redo. After
   5.0.0: #41 (a drive root reads the device object) and #90 (a trailing
   space in a folder name). Enhancements: #22, #49, #68, #77, #87.
4. `pwsh` 7.6.1 crashed three times during test runs on the ARM64
   workstation (x64 emulation), without module frames; none of the CI runs
   on native x64 on 2026-10-05 crashed.
5. Optional for the maintainer: delete the AppVeyor project and revoke its
   GitHub authorization, restrict wiki editing to collaborators, ask
   `Sup3rlativ3` to delete the Read the Docs project, and delete the branch
   `test/transfer`.
