---
status: current
last-verified: 2026-10-08
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Phase 2 of the quality gate before 5.0.0 (Decision 21), on the branch
`ai/release-5.0.0-rc6`, released as 5.0.0-rc6: tests until every code
path is tested or explained, live tests for the remaining cmdlets, and
test-first fixes of the known defects. The maintainer approved it on
2026-10-08. Then Phase 3 and 5.0.0; after 5.0.0 the repository is archived
in favor of WindowsAccessControl (Decision 18).

## Evidence

- 2026-10-08, Phase 1, measured on 5.0.0-rc5 (`fcb370e`):
  - The published package passes the live tests in both editions: 8 role
    runs, no failure.
  - As a basic user, the 11 tests that CI skips pass in both editions. The
    one failure, `Enable-Privileges should write one object per
    privilege`, assumes more than one privilege. Every test runs in at
    least one of four configurations (elevated or basic user, two
    editions), but CI runs only elevated.
  - The suite runs 55.9% of the C# lines and 37.4% of the branches
    (`techContext.md`, Validation). No line of `Test-Path2` and
    `Get-DiskSpace` runs; `Set-NTFSOwner` (46%) runs only as a setup step
    of another test; `Clear-NTFSAccess` and the access inheritance cmdlets
    run about 43%, `FileSystemSecurity2` 42%. No cmdlet calls the registry
    classes, `SimpleFileSystemAuditRule`, `PrivilegeEnabler`, or
    `FileSystemEffectivePermissionEntry` (244 lines).
  - 19 of the 36 cmdlets never ran over SMB, among them `Get-NTFSOwner`,
    `Set-NTFSOwner`, the audit inheritance cmdlets, and `Clear-NTFSAudit`;
    no account of another domain or forest ran; both ends of the lab run
    Windows Server 2025.
- Known defects from the reviews of #113 and #114 (`progress.md`, open
  work 3): `Move-Item2 -PassThru` returns the source item; the conflict
  checks of `Copy-Item2` and `Move-Item2` use `File.Exists` also for
  folders, maybe the cause of #21; an error while restoring the owner can
  hide the original one (R4); `Set-NTFSSecurityDescriptor -PassThru` reads
  the item again inside the retry (R5); the access check doesn't read
  `AUTHZ_ACCESS_REPLY.Error`, and its buffers aren't initialized. #110
  lists seven test follow-ups.
- #34: no reply from the tester by 06:44 UTC on 2026-10-08.

## Next step

Phase 2, one step at a time, each with evidence before the next:

1. Tests for the cmdlets without tests of their own: `Test-Path2`,
   `Get-DiskSpace`, `Set-NTFSOwner`, the link cmdlets,
   `Get-NTFSOrphanedAudit`, and `Get-NTFSSimpleAccess`.
2. The other parameter sets and error paths, such as the
   `-SecurityDescriptor` sets of the inheritance cmdlets and of
   `Clear-NTFSAccess`.
3. The paths of `Security2` that no test runs, and #110.
4. Test-first fixes of the known defects; behavior changes go to the
   maintainer (Decision 16).
5. A CI job as a basic user, live tests for the other cmdlets over SMB and
   for accounts of other forests, and a lab run.
6. Measure the coverage again, explain what remains, review, and prepare
   5.0.0-rc6.
