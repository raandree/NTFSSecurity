---
status: accepted
date: 2026-10-05
last-verified: 2026-10-05
owner: shared
source: maintainer decision D3 for the overnight run of 2026-10-04 (defect group E)
---

# Decision 13: Set-NTFSInheritance keeps entries like the dedicated cmdlets

- Choice: `Set-NTFSInheritance` uses the defaults of the dedicated cmdlets.
  `-AccessInheritanceEnabled $false` copies the inherited access entries
  into the DACL, like `Disable-NTFSAccessInheritance`, and
  `-AuditInheritanceEnabled $true` keeps the explicit audit entries, like
  `Enable-NTFSAuditInheritance`. The other two directions already matched.
  The same applies to a security descriptor in memory, whose kept entries
  stay marked as inherited until it is written.
- Way back: `Disable-NTFSAccessInheritance -RemoveInheritedAccessRules`
  removes the inherited access entries, and
  `Enable-NTFSAuditInheritance -RemoveExplicitAuditRules` removes the
  explicit audit entries. `Set-NTFSInheritance` gets no switches for that.
- Rationale: Before 5.0.0, two of the four directions removed entries,
  unlike the dedicated cmdlets. Turning access inheritance off on an item
  without explicit entries left an empty DACL, which denies access to
  everyone. 5.0.0 is a major version, so the change ships there, listed
  under `Changed` in the changelog.
- Related: `Clear-NTFSAccess -DisableInheritance` keeps discarding the
  inherited entries, because removing every entry is the purpose of that
  cmdlet; its page states the empty DACL and its risk (decision D2 of the
  same run). The audit switches were renamed to `-RemoveInheritedAuditRules`
  and `-RemoveExplicitAuditRules`, with the old names as aliases (D4).
- Rejected: adding `-RemoveInheritedAccessRules` and
  `-RemoveExplicitAuditRules` switches to `Set-NTFSInheritance`, which would
  duplicate the dedicated cmdlets.
