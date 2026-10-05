---
status: current
last-verified: 2026-10-05
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The overnight run of 2026-10-04/05 is finished. 5.0.0-rc2 waits on eight
stacked local branches (see `progress.md`): the maintainer pushes them,
opens one PR each against `master`, merges them in order with merge
commits, and tags `5.0.0-rc2` on the last merge commit once CI on `master`
is green. The run's report lists the commands, the PR descriptions, a
reply for each issue, and the open questions.

## Maintainer decisions for the run (2026-10-04)

- D1: the fixes ship in 5.0.0, under `[Unreleased]`; the behavior changes
  of D3 and D4 are listed under `Changed` with the way back.
- D2: `Clear-NTFSAccess -DisableInheritance` keeps leaving an empty DACL.
- D3: `Set-NTFSInheritance` keeps entries like the dedicated cmdlets
  (Decision 13).
- D4: `-RemoveInheritedAuditRules` and `-RemoveExplicitAuditRules`, with
  the old names as aliases.
- D5: `Get-FileHash2` works in PowerShell 7; `MACTripleDES` is deprecated.
- D6: only reproducible bugs are fixed; other behavior changes are
  questions for the maintainer.
- D7: Dependabot for `github-actions` only; AlphaFS 2.2.1 everywhere.
- D8: the manifest `Description` and a version-neutral README.
- D9: merged local branches deleted after the run.
- 2026-10-05: the report's recommendations accepted. #5 and #82 ship in
  5.0.0 as breaking changes; #34 for rc3 if a file server is available;
  #41 and #90 after 5.0.0; Minor findings become issues; the `pwsh` crash
  is watched in CI.

## Evidence

- Every branch tip: Release build without new warnings (296 at the top,
  305 at the baseline), docs checks clean, package dry run passed.
- Tests at the top branch: Windows PowerShell 423 passed, 26 skipped;
  PowerShell 7 394 passed, 55 skipped (449). The baseline had 268 tests.
- Tests that need privileges skip on the workstation and run in CI only;
  the PR descriptions list them.
- Reviews: one security review per PR; the Major findings were fixed in
  the PR that had them (PR 1: 1, PR 2: 5, PR 4: 2, PR 6: 1, PR 7: 3,
  PR 8: 2).

## Next step

The maintainer applies the repository settings, pushes the eight branches,
opens and merges the PRs in order, and tags `5.0.0-rc2` once CI on
`master` is green.
