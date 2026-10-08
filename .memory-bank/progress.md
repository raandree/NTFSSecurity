---
status: current
last-verified: 2026-10-08
owner: active-agent
source: repository evidence
---

# Progress

## Current status

5.0.0-rc5 is on the PowerShell Gallery and in the GitHub releases,
published by CI on 2026-10-08 from the tag `5.0.0-rc5` on `master`
(`fcb370e`, the merge of #114; Decision 12). Phase 2 of the quality gate
(Decision 21) is complete on the local branch `ai/release-5.0.0-rc6`: the
candidate 5.0.0-rc6 (`acfe3af`) passed the suite in four configurations,
one `security-reviewer` pass, and the lab acceptance. It waits for the
maintainer to push, merge, and tag it; Phase 3 follows. The stable Gallery
version is still 4.2.6. NTFSSecurity will be archived soon; its users move
to WindowsAccessControl (Decision 18).

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
- 2026-10-08: #114 merged (`fcb370e`); the tag `5.0.0-rc5` published it to
  the Gallery and the GitHub releases, whose `NTFSSecurity.zip` holds the
  same 11 files. Phase 1 of the quality gate (Decision 21) measured rc5:
  the published package passes the live tests in both editions; the 11
  tests that need a session without the Security privilege pass as a basic
  user, so every test runs in at least one configuration, but CI runs only
  elevated; the suite runs 55.9% of the C# lines and 37.4% of the branches.
  The maintainer approved Phase 2.
- 2026-10-08: Phase 2, step 1 on `ai/release-5.0.0-rc6` (local): tests for
  `Set-NTFSOwner`, `Test-Path2`, `Get-DiskSpace`, and the link cmdlets
  (suite: 555 tests). Fixed test-first: the privileges stayed enabled after
  an early stop; `Test-Path2` stopped for invalid characters in Windows
  PowerShell; and, from one `security-reviewer` pass, the privilege cleanup
  decided on stale states, a defect since 4.2.6. The page of
  `New-NTFSSymbolicLink` was corrected after a lab check of Developer Mode.
- 2026-10-08: Phase 2 finished on `ai/release-5.0.0-rc6` (local). Tests for
  `Get-NTFSOrphanedAudit`, `Get-NTFSSimpleAccess`, the
  `-SecurityDescriptor` parameter sets, the error contracts of all path
  cmdlets, and #110. Fixed test-first: `Get-NTFSSimpleAccess` (`ReadData`,
  relative paths), `Copy-Item2` and `Move-Item2` (folder conflicts, the
  missing destination folder of #21), the hard-link cmdlets on shares,
  `Set-NTFSSecurityDescriptor -PassThru` (R5), and the error ID of
  `Get-NTFSOrphanedAccess`; from the coverage report, relative paths that
  start with a dot (every cmdlet acted on the item without the first two
  characters), comparing output objects (`InvalidCastException`), and
  `InheritedFrom`. CI runs the suite as a basic user too; the live tests
  cover all cmdlet groups and accounts of three more domains. Suite: 677
  tests, none failed, none skipped in every configuration; C# coverage
  68.1% of the lines and 44.3% of the branches (rc5: 58.1% and 38.0%,
  measured again; the first measurements counted one of four runs). Two
  `security-reviewer` passes; the lab acceptance of `7b0781f` passed
  (`Tests/Lab/Acceptance-2026-10-08-5.0.0-rc6.md`).

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

1. Quality gate before 5.0.0 (Decision 21): Phase 2 is done on the branch
   `ai/release-5.0.0-rc6` (`activeContext.md`); the maintainer pushes it,
   merges the pull request, and tags 5.0.0-rc6, and the live tests run
   against the published package. Phase 3 runs the live tests on more
   operating systems. Then release
   5.0.0 through CI (Decision 12): remove the label, date `[Unreleased]` as
   `[5.0.0]`, add the last prerelease to `$publishedVersions`, and tag
   `5.0.0` (steps in `Docs/Contributing/05-Releasing.md`). #34 stays open
   with Bug and Help Wanted until a tester with a file server that refuses
   the owner confirms the fix, or until 5.0.0 ships.
2. Issues: the rc6 branch addresses the seven items of #110 (tests); the
   pull request names it without a closing keyword, so the maintainer
   closes it after the merge. #21 (a misleading error of `Move-Item2`) got
   a fix in rc6 that names the missing destination folder. #68
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
   password string in memory, disabling the role accounts after a run); of
   rc6, a privilege that fails to be disabled isn't tried again by
   `Dispose` (finding 2, not reproducible).
4. Behavior changes found in Phase 2, for the maintainer (Decision 16):
   `Get-NTFSOrphanedAudit` returns nothing without the Security privilege,
   while `Get-NTFSAudit` writes `ReadSecurityError`;
   `Get-NTFSSimpleAccess` skips a folder whose parent it didn't process;
   `New-NTFSSymbolicLink` could create links without the privilege in
   Developer Mode (flag `SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE`, with
   a fallback before Windows 10 1703); `-WhatIf` names a conflict in a
   verbose message instead of a warning (R7); the fallback warning of
   `Get-NTFSEffectiveAccess` doesn't name the server; `Move-Item2` can't
   move a folder to another volume; `New-NTFSHardLink` stops with a
   terminating error for a folder, unlike `Get-NTFSHardLink` (rc6 review,
   finding 11). Taken as an assumption in rc6, for review: `Copy-Item2`
   no longer creates the missing folders of a destination for a folder.
   Found by the coverage report of rc6: `-Target` of the link cmdlets is
   optional and means the current location when it's omitted; equality of
   entries and descriptors is the identity of the wrapped .NET object, so
   two reads of the same entry differ for `Compare-Object` and
   `Select-Object -Unique` (value equality would be a behavior change); 400
   points of code that nothing calls besides the 244 lines of unused
   classes (Phase 3).
5. `pwsh` 7.6.1 crashed three times during test runs on the ARM64
   workstation (x64 emulation), without module frames; none of the CI runs
   on native x64 on 2026-10-05 crashed.
6. Optional for the maintainer: delete the AppVeyor project and revoke its
   GitHub authorization, restrict wiki editing to collaborators, ask
   `Sup3rlativ3` to delete the Read the Docs project, and delete the branch
   `test/transfer`. In the lab, delete the checkpoints
   `ntfs-rc6-*-before-acceptance` of the six machines when they are no
   longer needed.
7. Reachable code that no test runs (coverage report of rc6, ranked by
   impact; about 300 points): `Remove-Item2` on folders (`-Recurse`,
   `-Force`, `DeleteError`); the owner restore after taking ownership
   (`RestoreOwnerError`); the inheritance cmdlets on folders and
   `Set-NTFSInheritance -AccessInheritanceEnabled $true`; the mapping of
   all 13 `-AppliesTo` values and the flag parameters of
   `Remove-NTFSAccess`, `Add-NTFSAudit`, and `Remove-NTFSAudit`; the
   switches and errors of `Get-ChildItem2`; the table views and
   `InheritedFrom` in them; `Move-Item2 -Force`; account input errors;
   `-PassThru` after success of the audit and inheritance cmdlets;
   `Set-NTFSSecurityDescriptor` failures; the audit cmdlets without the
   Security privilege on a local item; `Get-NTFSEffectiveAccess` for an
   unresolvable SID; failed ownership retries of `Clear-NTFSAccess` and
   `Set-NTFSInheritance`. A display limit, not a defect: a conditional ACE
   shows as an unconditional entry, because the .NET rules have no
   condition.
