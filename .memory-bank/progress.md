---
status: current
last-verified: 2026-10-07
owner: active-agent
source: repository evidence
---

# Progress

## Current status

5.0.0-rc4 is on the PowerShell Gallery and in the GitHub releases,
published by CI from the tag `5.0.0-rc4` on `master` (`01d9264`, the merge
of #113) on 2026-10-06 (Decision 12). It adds to 5.0.0-rc3 the fixes of the
issues #41, #108, #109, and #111 and of the leftovers of the rc3 review.
5.0.0-rc5 is prepared on the branch `ai/release-5.0.0-rc5`: the live tests
in a lab (Decision 20) and the fix of `Get-NTFSEffectiveAccess -ServerName`
that they found. The stable Gallery version is still 4.2.6. NTFSSecurity
will be archived soon; its users move to WindowsAccessControl
(Decision 18).

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
- 2026-10-06: the issues got their labels (Decision 17). The maintainer
  decided to publish 5.0.0-rc3 before 5.0.0 and to archive the project in
  favor of WindowsAccessControl (Decision 18); the README, the docs home,
  and the changelog announce it.
- 2026-10-06: 5.0.0-rc3 (#112): the access and audit cmdlets write only
  the section that they change, which fixes #34 and the inherited entries
  that elevated sessions copied as explicit ones (Decision 19). #67 has its
  cause outside the module (a share root over UNC can't re-inherit), is
  explained in `Docs/FAQ.md`, and was closed as not planned. One
  `security-reviewer` pass approved the branch. The PR description said
  "fixes #34", so the merge closed #34; it was reopened for a tester.
- 2026-10-06: 5.0.0-rc4 (#113), test-first: drive and volume roots read
  and change their root folder, not the device (#41); the audit cmdlets
  reject a descriptor without the audit entries (#109); `-WhatIf` previews
  `Copy-Item2` and `Move-Item2` despite an existing destination (#108);
  small items (#111). One `security-reviewer` pass approved it; its Minor
  findings R1, R2, R6, and R8 were fixed before the merge. #41, #108,
  #109, and #111 closed as completed, #90 and #107 as not planned.
- 2026-10-07: live tests in the lab of WindowsAccessControl (Decision 20)
  against 5.0.0-rc2 and 5.0.0-rc4 in both editions: rc2 fails #34 over SMB
  with error 1307 for `Add-NTFSAccess`, `Clear-NTFSAccess`, and
  `Set-NTFSSecurityDescriptor`; rc4 passes the four cases, except
  `Get-NTFSEffectiveAccess -ServerName` with a computer that can't be
  reached, which returned no access since before rc1. The maintainer chose
  to fix it test-first in 5.0.0-rc5; the branch build passes all live tests
  and the suite. One `security-reviewer` pass approved it with minor
  findings (`activeContext.md`).

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

1. Publish 5.0.0-rc5 (merge, then tag), check its package in the lab with
   `Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 -Version 5.0.0-rc5`, and then
   release 5.0.0 through CI (Decision 12) with the tester feedback in #34:
   remove the label, date `[Unreleased]` as `[5.0.0]`, add `5.0.0-rc5` to
   `$publishedVersions`, and tag `5.0.0` (steps in
   `Docs/Contributing/05-Releasing.md`). #34 stays open with Bug and Help
   Wanted until a tester with a file server that refuses the owner
   confirms the fix, or until 5.0.0 ships.
2. Issues: #110 (tests) is the open follow-up of the review findings; #68
   tracks `-WhatIf` and `-Confirm` for every cmdlet that changes security.
   The labels follow Decision 17; #16, #21, #45, and #89 wait for their
   reporters (Needs Info). Not planned for 5.0.0: the enhancements #22,
   #49, #68, #77, #87.
3. Review findings, not filed: of rc3, an extra DACL read and four SDDL
   snapshots on read paths, and a duplicate SACL check; of rc4, R3 to R5,
   R7, and five older defects, listed in the description of #113, among
   them the accounts filter that `RemoveFileSystemAccessRuleAll` and
   `RemoveFileSystemAuditRuleAll` ignore, which no cmdlet passes; of rc5,
   the bare `catch` in `Win32.GetEffectiveAccess`, the unchecked
   `AUTHZ_ACCESS_REPLY.Error`, a fallback warning without the server name,
   and hardening of the lab controller (guards in the setup blocks,
   interpolated `-EncodedCommand` paths, CredSSP by IP address, the
   password string in memory, disabling the role accounts after a run).
4. `pwsh` 7.6.1 crashed three times during test runs on the ARM64
   workstation (x64 emulation), without module frames; none of the CI runs
   on native x64 on 2026-10-05 crashed.
5. Optional for the maintainer: delete the AppVeyor project and revoke its
   GitHub authorization, restrict wiki editing to collaborators, ask
   `Sup3rlativ3` to delete the Read the Docs project, and delete the branch
   `test/transfer`.
