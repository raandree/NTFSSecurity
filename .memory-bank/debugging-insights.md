---
status: current
last-verified: 2026-10-10
owner: software-engineer
source: Handoff 5 (the coverage unknowns): probes, red and green runs, and the independent review
---

# Debugging insights

Recurring defect classes and how to find them. Evidence is in
`Tests/Coverage/Quality-Gate-Unknowns-2026-10-10.md`; a fix needs a test that
fails without it (Decision 16).

## Culture-sensitive comparison (`tr-TR`)

- With `tr-TR`, `I` and `i` are different letters, so a comparison that takes
  the culture of the thread drops or misses items: `string.Equals` without a
  comparer, a case-insensitive `Regex`, a `WildcardPattern` without
  `CultureInvariant`. Handoff 5 found two defects of this class:
  `IdentityReference2.Equals(object)` called with a name (now
  `OrdinalIgnoreCase`) and `Get-ChildItem2 -Filter` (`index*` did not list
  `Index.txt`).
- A scan of the C# is not enough: AlphaFS 2.2 builds a culture-sensitive regex
  from a search pattern. `Get-ChildItem2` therefore enumerates under
  `InvariantCultureScope` (around the creation of the enumerator and each
  `MoveNext`, never across a `WriteObject`) and its own `WildcardPattern` has
  `CultureInvariant`. Check any new library call that takes a user pattern.
- PowerShell `-eq`, `-contains`, and `-in` do not take the thread culture;
  only the .NET method call failed. Probe a claim before it enters the
  changelog or a report (the first wording named `-eq` and was wrong).
- A test sets the culture of the thread, restores it in `finally`, names the
  rows that differ (`index*`, `*.INI`), keeps a control (`INDEX*`), and is
  proved red on the previous build and green on the new one in all four
  configurations (`Tests/ItemCmdlets.Tests.ps1`, `Tests/ObjectApis.Tests.ps1`).

## A test oracle that is wrong on a domain member

- `Get-Acl -Audit` reads the SACL with the other sections and reports an item
  without audit entries as protected (Windows Server 2019, 2022, and 2025
  domain members, Windows 11); the module and `Get-NTFSInheritance` read the
  SACL alone. Tests read the flag with .NET `GetAccessControl(Audit)`
  (`Get-TestAuditAcl`). A suite that is green on the host proves nothing about
  an oracle: run a new test on a domain member before calling it done.

## A piped property and the parameter set

- An object with a property `AppliesTo`, piped into `Add-` or
  `Remove-NTFSAccess` or `-NTFSAudit` with a path, binds the default
  `PathComplex` set and drops the property; with a descriptor it binds
  `SDSimple`. A test that means the Simple set names `-AppliesTo` and asserts
  the scope it gets (a probe that tells the sets uses an entry of the default
  scope: removing `ThisFolderOnly` from it leaves the `InheritOnly` part).
