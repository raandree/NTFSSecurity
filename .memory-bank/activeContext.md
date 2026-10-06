---
status: current
last-verified: 2026-10-06
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

5.0.0-rc3, before 5.0.0 (maintainer decision of 2026-10-06): the access and
audit cmdlets read and write only the sections of the security descriptor
that they change, which fixes #34 and the copied inherited entries, and #67
is reproduced and fixed or explained. NTFSSecurity will be archived soon;
the README and the docs point users to WindowsAccessControl (Decision 18).
The maintainer has a handoff for rc3, outside the repository.

## Evidence

- #34 reproduces locally with 5.0.0-rc2 (2026-10-06): on a file owned by
  `NT SERVICE\TrustedInstaller`, with `EnablePrivileges = $false`,
  `Add-NTFSAccess` fails with "(1307) This security ID may not be assigned
  as the owner of this object" (`AddAceError`), because it writes the
  unchanged owner back; `icacls /grant` and `Remove-NTFSAccess`, which
  write only the DACL, succeed, and with the Restore privilege enabled
  `Add-NTFSAccess` succeeds. A test can therefore run in CI without a file
  server.
- Elevated, `Add-NTFSAccess` and `Add-NTFSAudit` read the DACL together
  with the SACL. For a DACL without the auto-inherit flag, Windows then
  returns the inherited entries without their inherited flag, and the
  write stores them as explicit copies (found 2026-10-05).
- `new FileSystemSecurity2(item)` reads all sections it can, and `Write()`
  writes what the descriptor holds. Callers that write: adding access or
  audit entries, removing all entries of an account, and
  `Set-NTFSSecurityDescriptor` for a descriptor from
  `Get-NTFSSecurityDescriptor`. Removing a single entry and the inheritance
  cmdlets already read and write one section.
- 5.0.0-rc2 is published (2026-10-05); CI on `master` passed; the issues
  are answered, labeled (Decision 17), and tracked as #107 to #111.

## Next step

Implement 5.0.0-rc3 test-first on a topic branch, starting with a failing
test for #34 that uses the reproduction above.
