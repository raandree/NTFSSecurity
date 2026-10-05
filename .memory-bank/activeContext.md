---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Overnight run 2026-10-04/05 (autopilot, maintainer asleep): fix the code
defects A to D of `progress.md`, implement the maintainer's E decisions,
triage the 37 open issues, and prepare 5.0.0-rc2. Eight stacked local
branches, each a PR against `master`, to be merged in this order with merge
commits: `ai/maintenance`, `ai/defects-a`, `ai/defects-b`, `ai/defects-c`,
`ai/defects-d`, `ai/decisions-e`, `ai/issue-fixes`,
`ai/release-5.0.0-rc2`. Nothing is pushed; the maintainer pushes, opens
the PRs, and tags `5.0.0-rc2` after the merges.

## Maintainer decisions for the run (2026-10-04)

- D1: the fixes ship in 5.0.0; entries go under `[Unreleased]` (`Fixed`;
  intended behavior changes under `Changed` with the way back). The last
  PR sets `Prerelease = 'rc2'`.
- D2: `Clear-NTFSAccess -DisableInheritance` keeps leaving an empty DACL;
  the page states the result and the risk.
- D3: `Set-NTFSInheritance` keeps entries like the dedicated cmdlets.
- D4: `-RemoveInheritedAuditRules` and `-RemoveExplicitAuditRules`, with
  the `*AccessRules` names as aliases.
- D5: `Get-FileHash2` works in PowerShell 7 for every algorithm .NET has;
  a missing one fails only when requested.
- D7: Dependabot for `github-actions` only; AlphaFS 2.2.1 in
  `NTFSSecurity\packages.config` (no upgrade, no changelog entry).

## Evidence

- Baseline at `e0f5366` (Release build, workstation): Windows PowerShell
  261 passed, 7 skipped; PowerShell 7 232 passed, 36 skipped (268 tests).
- `ai/maintenance` adds `Tests\Repository.Tests.ps1` (8 tests): Windows
  PowerShell 269 passed, 7 skipped; PowerShell 7 240 passed, 36 skipped.
  Review: Dependabot PRs ran unreviewed actions in a job with
  `contents: write`; the wiki preview is now read-only (`publish-wiki`).
- `ai/defects-a` fixes defects 1 to 13 and the same repeat bug in
  `Get-NTFSAccess` (found with 4); its review fixes are in the last
  commit: Windows PowerShell 312 passed, 17 skipped; PowerShell 7 282
  passed, 47 skipped (329 tests).
- `ai/defects-b` fixes defects 14 to 17 (`-AppliesTo` is mandatory in the
  `Simple` sets; `-RemoveSpecific` is back): Windows PowerShell 333 passed,
  19 skipped; PowerShell 7 303 passed, 49 skipped (352 tests).
- `ai/defects-c` fixes defects 18 to 21, the same missing `continue` in
  `Remove-NTFSAudit`, and a stale hash in `Get-FileHash2`. Its review
  found that a failed retry after taking ownership left the owner changed;
  `BaseCmdlet.InvokeAsOwner` now restores it: Windows PowerShell 356
  passed, 20 skipped; PowerShell 7 325 passed, 51 skipped (376 tests).
- `ai/defects-d` fixes defects 22 to 24 and `-PassThru` under `-WhatIf` in
  the `*-Item2` cmdlets: Windows PowerShell 379 passed, 23 skipped;
  PowerShell 7 348 passed, 54 skipped (402 tests).

- `ai/decisions-e` implements D2 to D5 (Decision 13): Windows PowerShell
  395 passed, 26 skipped; PowerShell 7 366 passed, 55 skipped (421
  tests). `Get-FileHash2` tests now run in PowerShell 7 as well.

## Next step

The bugs from the issue triage (`ai/issue-fixes`), then 5.0.0-rc2.
