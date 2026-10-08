---
status: current
last-verified: 2026-10-08
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Phase 2 of the quality gate before 5.0.0 (Decision 21) is complete on the
local branch `ai/release-5.0.0-rc6`, candidate `7b0781f`. The maintainer
pushes the branch, merges the pull request after CI, and tags 5.0.0-rc6.
Then Phase 3 (live tests on more operating systems) and 5.0.0; after
5.0.0 the repository is archived in favor of WindowsAccessControl
(Decision 18).

## Evidence

- 2026-10-08, Phase 2 on `ai/release-5.0.0-rc6`, 31 commits on `fcb370e`
  (5.0.0-rc5); the candidate is `7b0781f`:
  - The suite has 684 tests. Elevated: 662 passed and 22 skipped in
    Windows PowerShell 5.1, 632 and 52 in PowerShell 7. As a basic user
    through `Invoke-TestsAsBasicUser.ps1`: 590 and 94, 560 and 124. No
    failure, and no test is skipped in all four configurations; CI runs
    all four since this branch.
  - C# coverage of all four configurations (AltCover without `--save`,
    `techContext.md`): 68.1% of the lines and 44.3% of the branches on
    `1b9edbb`; rc5 58.1% and 38.0%. The earlier figures counted one of
    the four runs. Of the 972 points that no test ran at `e2b6b24`
    (without the classes that no cmdlet calls), 400 are code that nothing
    calls, 107 defensive guards, 74 need a failure of Windows, 4 need the
    lab, and 387 are reachable; 51 of those ran in runs that the first
    measurement missed, and the top items of the rest are in
    `progress.md`, open work 7.
  - Fixed test-first: `Get-NTFSSimpleAccess` (`ReadData`, the parent of a
    relative path); `Copy-Item2` and `Move-Item2` (a folder at the
    destination, the missing destination folder of #21, also with
    `-WhatIf`); the hard-link cmdlets on shares and at folders;
    `Set-NTFSSecurityDescriptor -PassThru` (R5); the error ID of
    `Get-NTFSOrphanedAccess`; relative paths that start with a dot, which
    every cmdlet shortened by two characters (`Remove-Item2 .x` removed
    another item); comparing entries and descriptors
    (`InvalidCastException`, also `Compare-Object` in PowerShell 7) and
    their conversions; `InheritedFrom` with `-ExcludeExplicit` and for a
    descriptor with audit entries (`ArgumentOutOfRangeException`).
    `Copy-Item2` no longer creates the missing folders of a destination
    for a folder (assumption, flagged for the maintainer).
  - Live tests: cases 4b to 9 and accounts of `b.forest1.net`,
    `forest2.net`, and `forest3.net`. The lab acceptance passed for
    `acfe3af`, `1b9edbb`, and `7b0781f` (326 tests each, none failed;
    `Tests/Lab/Acceptance-2026-10-08-5.0.0-rc6.md`). Baseline: the
    published 5.0.0-rc5 fails only the two hard-link tests of case 8. The
    fixture was removed and the removal checked after each run; three
    checkpoints `ntfs-rc6-*-before-acceptance` stay on six machines.
  - `Get-NTFSEffectiveAccess -ServerName` needs administrators or
    Access Control Assistance Operators on the named computer (lab probe,
    documented).
  - Two `security-reviewer` passes approved the branch with no Blocker or
    Major finding: `fcb370e..e2b6b24` (findings 1, 4, 5, 10 fixed in
    `acfe3af`) and `e2b6b24..1b9edbb` (findings 1, 2, 6, 7 fixed in
    `7b0781f`). Not fixed: a failed privilege disable isn't tried again,
    and a non-qualified ACE could shift `InheritedFrom` (neither
    reproducible); `New-NTFSHardLink` stays terminating for a folder (a
    behavior change for the maintainer).
- #34: no reply from the tester since 2026-10-06.

## Next step

1. The maintainer pushes the branch, opens the pull request, merges it
   after CI, and tags `5.0.0-rc6`; then the live tests run against the
   published package (`-Version 5.0.0-rc6`). The first CI run is the first
   run of `Invoke-TestsAsBasicUser.ps1` on a GitHub runner.
2. The maintainer decides the behavior changes in `progress.md`, open
   work 4 (Decision 16), and the scope of Phase 3: the operating systems,
   the code that nothing calls, and file servers that aren't Windows
   (#34).
