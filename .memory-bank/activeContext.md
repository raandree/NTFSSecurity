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
  `Get-NTFSAccess` (found with 4): Windows PowerShell 310 passed, 17
  skipped; PowerShell 7 280 passed, 47 skipped (327 tests). 10 tests need
  privileges and run only in CI.
- `ai/defects-b` fixes defects 14 to 17 (`-AppliesTo` is mandatory in the
  `Simple` sets; `-RemoveSpecific` is back): Windows PowerShell 331 passed,
  19 skipped; PowerShell 7 301 passed, 49 skipped (350 tests).

## Next step

Group C (18 to 21) on `ai/defects-c`, then D, the E decisions, and the
bugs from the issue triage (`ai/issue-fixes`).
