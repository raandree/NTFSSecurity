---
status: accepted
date: 2026-10-11
last-verified: 2026-10-11
owner: shared
source: maintainer decision of 2026-10-11
---

# Decision 26: Add and Remove for access and audit declare no default parameter set

- Choice: `Add-NTFSAccess`, `Remove-NTFSAccess`, `Add-NTFSAudit`, and
  `Remove-NTFSAudit` declare no `DefaultParameterSetName` (maintainer,
  2026-10-11; `93ed2c7`). An object piped with a path binds `PathSimple` when
  it has `AppliesTo`, and `PathComplex` when it has `InheritanceFlags`,
  `PropagationFlags`, or neither (the default scope). An object that has
  `AppliesTo` and one of the flags fails with `AmbiguousParameterSet`, like the
  same named parameters.
- Rationale: With `PathComplex` as the default, an object that satisfied its
  mandatory parameters made the binder settle on it, and a piped `AppliesTo`
  was dropped without a message (a silent change of the scope). `4b1abc9` had
  made `AppliesTo` mandatory in the Simple sets, so the default no longer
  decided any named call.
- Consequence: a script that piped objects with `AppliesTo` and the flags
  together got the flags before and gets an error now; so does an object that
  has both `Path` and `SecurityDescriptor`, where the path won. An
  `AppliesTo` that is `$null` fails to bind for that object (a CSV row with
  fewer fields than its header has `$null` there); a call with neither
  `-Path` nor `-SecurityDescriptor` fails with `AmbiguousParameterSet` instead
  of a missing-parameter error (CHANGELOG, Fixed). A value that PowerShell
  cannot convert to a scope (the blank cell that `Import-Csv` reads, a typo)
  is ignored silently, and the object is handled as one without `AppliesTo`:
  its own flags, or the default scope when it has none. The binder swallows a
  value that it cannot convert, so failing loudly needs a design change
  (report, open item 3). Named calls,
  `-SecurityDescriptor` calls without `AppliesTo`, and
  `Get-NTFSAccess | Add-NTFSAccess -Path` do not change. The syntax lists
  `PathSimple` first, because PowerShell orders the sets by declaration.
- Follow-up: the third independent review found that `ProcessRecord` wrote
  the scope converted from `AppliesTo` into the fields behind the flag
  parameters, which PowerShell does not reset between piped objects. The flags
  of a record are locals since `9783d2a`; rc7 had the defect for piped
  `-SecurityDescriptor` objects. The reviewer's checks found that "an empty
  `AppliesTo` fails to bind" was true for `$null` only (`7bc7925`), and that
  the sentence about unconvertible values was too narrow (`2112ee3`).
- Evidence: report `Tests/Coverage/Quality-Gate-Unknowns-2026-10-10.md`
  (decision 23; the section on the fix of the piped `AppliesTo`), the tests in
  `Tests/ParameterSets.Access.Tests.ps1` and `Tests/ParameterSets.Audit.Tests.ps1`
  (red before, green after, in four configurations), and
  `.memory-bank/debugging-insights.md`.
