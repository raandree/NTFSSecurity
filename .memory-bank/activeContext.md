---
status: current
last-verified: 2026-10-07
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

5.0.0-rc5, prepared on the branch `ai/release-5.0.0-rc5`: the live tests
in `Tests\Lab` (Decision 20) and the fix of
`Get-NTFSEffectiveAccess -ServerName` that they found. The maintainer
pushes the branch, opens and merges the pull request, and tags
`5.0.0-rc5`; CI publishes it (Decision 12). Then, with the tester feedback
in #34, he decides on 5.0.0. After 5.0.0 the repository is archived in
favor of WindowsAccessControl (Decision 18).

## Evidence

- 2026-10-07: the live tests ran in the lab of WindowsAccessControl
  (`F1ADC1`, `F1AFile2`, `F1AFile1` in `a.forest1.net`) against the Gallery
  packages of 5.0.0-rc2 and 5.0.0-rc4 and against the branch build, in
  Windows PowerShell 5.1 and PowerShell 7, with the same results in both:
  - Case 1 (#34 over SMB): rc2 fails `Add-NTFSAccess`, `Clear-NTFSAccess`,
    and `Set-NTFSSecurityDescriptor` with error 1307, on folders with and
    without the auto-inherit flag; the other four cmdlets succeed in rc2
    too. rc4 passes all seven and keeps Administrators as the owner.
  - Case 2: the administrators of the file server read, add, and remove
    audit entries over SMB; the delegated account gets the errors that the
    cmdlet pages describe, and the folders stay unchanged. Same in rc2.
  - Case 3: with `-ServerName` of the file server, the result includes its
    local group, without a warning; without it, only the domain groups
    count. With a computer that can't be reached, rc2 and rc4 returned no
    access, because error 1722 was swallowed; fixed on the branch.
  - Case 4, long paths on the share, and #108 pass; #108 fails in rc2.
  - The branch build passes every live test, and the 499 tests of `Tests`
    in both editions.
- One `security-reviewer` pass approved the branch with minor findings;
  the assertion of the fallback warning and the path guard of the live
  tests were hardened. Deferred: the bare `catch` in
  `Win32.GetEffectiveAccess`, which still swallows any other error of the
  remote initialization (not reproducible: for a user who isn't an
  administrator of the file server, the cmdlet writes "Access is denied");
  the unchecked `AUTHZ_ACCESS_REPLY.Error`; a fallback warning that names
  the server and the error, which would change behavior (Decision 16).
- #34: no report from the tester by 16:00 UTC on 2026-10-07; he announced
  results against two file servers, one of them IBM ESS, for that day.
- The lab keeps the accounts, the share, and the folders of the last run;
  `Invoke-NTFSSecurityLabTest.ps1 -RemoveFixture` removes them.

## Next step

The maintainer runs the push and pull request commands of the session of
2026-10-07, merges, and tags `5.0.0-rc5`. Then check the published package
with `Invoke-NTFSSecurityLabTest.ps1 -Version 5.0.0-rc5`, wait for the #34
feedback, and release 5.0.0 as `progress.md` describes.
