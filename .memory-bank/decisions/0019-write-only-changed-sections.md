---
status: accepted
date: 2026-10-06
last-verified: 2026-10-06
owner: shared
source: maintainer decisions of 2026-10-06 for 5.0.0-rc3 (#112)
---

# Decision 19: Cmdlets write only the sections that they change

- Choice: A cmdlet that changes a file or folder reads and writes only the
  section of the security descriptor that it changes, and names that
  section in the write: the access and access inheritance cmdlets the
  DACL, the audit cmdlets the SACL. `Set-NTFSSecurityDescriptor` writes
  only the sections that changed since the descriptor was read or last
  written; a descriptor without changes writes nothing, and `-Verbose`
  names the sections. When the descriptor of `Get-NTFSSecurityDescriptor`
  includes the SACL, it reads the DACL in a separate call. `Clear-NTFSAudit`
  reports an error without the Security privilege, like the other audit
  cmdlets.
- Rationale: For a DACL without the auto-inherit flag, Windows returns the
  owner and the group even when only the DACL is read, and writing every
  section of the descriptor writes the owner back. Where the account may not
  assign that owner, that fails with error 1307 (#34). Read together with
  the SACL, such a DACL loses the inherited flag of its entries when the
  parent folder has no SACL, and writing it back stored them as explicit
  copies.
- Rejected: writing every section in turn and ignoring the errors, the
  approach of the branch `fix/#34` (2023).
- Applied: 5.0.0-rc3, #112.
