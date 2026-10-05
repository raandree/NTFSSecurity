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

## Evidence

- Every branch tip: Release build without new warnings (296 at the top,
  305 at the baseline), docs checks clean, package dry run passed.
- Tests at the top branch: Windows PowerShell 405 passed, 26 skipped;
  PowerShell 7 376 passed, 55 skipped (431). The baseline had 268 tests.
- Tests that need privileges skip on the workstation and run in CI only;
  the PR descriptions list them.
- Reviews: one security review per PR; the Major findings were fixed in
  the PR that had them (PR 1: 1, PR 2: 5, PR 4: 2, PR 6: 1).

## Next step

The maintainer reads the report, pushes the branches, opens and merges the
PRs, tags `5.0.0-rc2`, and decides #5 (`Get-ChildItem2 -Attributes`).
