---
status: current
last-verified: 2026-10-06
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Live tests of 5.0.0-rc4 in a lab, which the maintainer decided on
2026-10-06 to run before 5.0.0. He continues on another workstation that
has his lab script. 5.0.0 waits for these results and for the tester
feedback in #34; then the repository is archived in favor of
WindowsAccessControl (Decision 18).

## Evidence

- 2026-10-06: 5.0.0-rc4 is published from the tag `5.0.0-rc4` on
  `01d9264`, the merge commit of #113, and verified from the Gallery
  package in both editions; its issues are closed (progress).
- The Pester tests run only on standalone machines against local NTFS
  folders, with local and well-known accounts. No test uses a UNC path, a
  share, a domain account, or `Get-NTFSEffectiveAccess -ServerName`, which
  calls `AuthzInitializeRemoteResourceManager` over RPC. 5.0.0 changed no
  code that is specific to domains or SMB.
- In #34, the tester wrote on 2026-10-06 that the owner problem also exists
  on their IBM ESS system, and that he reports rc3 results against both
  their file servers on 2026-10-07. No lab reproduces IBM ESS.
- The second workstation has Hyper-V and AutomatedLab 5.61, but no
  LabSources folder, ISO, or lab.
- Hand commands to the maintainer as fenced code blocks at the end of the
  reply, and end the turn there; never put them in the question dialog,
  which also covers a reply before it. A pull request names an issue
  without a closing keyword unless the merge should close it (techContext).

## Next step

Build the lab with the maintainer's script: a domain controller, a file
server with a share, and a client. From the client, run live tests against
5.0.0-rc2 as the baseline and 5.0.0-rc4, in Windows PowerShell 5.1 and
PowerShell 7:

1. #34 over SMB: a domain user who isn't an admin on the file server, with
   Full Control on a share folder owned by Administrators, runs the access
   and inheritance cmdlets on its UNC path. rc2 should fail with (1307);
   rc4 should succeed and keep the owner.
2. The audit cmdlets over SMB, where the file server, not the client,
   checks the Security privilege: as a user with and without it there.
3. `Get-NTFSEffectiveAccess` for domain accounts with nested groups, and
   with `-ServerName`.
4. `Get-NTFSOrphanedAccess` with the entry of a deleted domain account.

Then, with the #34 feedback, release 5.0.0 as `progress.md` describes.
