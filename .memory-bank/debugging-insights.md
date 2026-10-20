---
status: current
last-verified: 2026-10-20
owner: software-engineer
source: Handoff 5 (the coverage unknowns) and the rc8 fix: probes, red and green runs, and the independent reviews
---

# Debugging insights

Recurring defect classes and how to find them. Evidence is in
`Tests/Coverage/Quality-Gate-Unknowns-2026-10-10.md`; a fix needs a test that
fails without it (Decision 16).

## Culture-sensitive comparison (`tr-TR`)

- With `tr-TR`, `I` and `i` are different letters, so a comparison that takes
  the culture of the thread drops or misses items: `ToLower` or `ToUpper`,
  `Compare`, `StartsWith`, `EndsWith`, or `IndexOf(string)` without a
  `StringComparison`, a case-insensitive `Regex`, a `WildcardPattern` without
  `CultureInvariant` (`string.Equals(a, b)` and `==` are ordinal and safe).
  Handoff 5 found two defects of this class: `IdentityReference2.Equals(object)`
  called with a name, which lowercased both sides (now `OrdinalIgnoreCase`),
  and `Get-ChildItem2 -Filter` (`index*` did not list `Index.txt`).
- A scan of the C# is not enough: AlphaFS 2.2 builds a culture-sensitive regex
  from a search pattern. `Get-ChildItem2` therefore enumerates under
  `InvariantCultureScope` (around the creation of the enumerator and each
  `MoveNext`, never across a `WriteObject`) and its own `WildcardPattern` has
  `CultureInvariant`. Check any new library call that takes a user pattern.
- PowerShell `-eq`, `-contains`, and `-in` do not take the thread culture;
  only the .NET method call failed. Probe a claim before it enters the
  changelog or a report (the first wording named `-eq` and was wrong).
- A test sets the culture of the thread, restores it in `finally`, names the
  rows that differ (`index*`, `*.INI`), keeps a control (`INDEX*`), reads the
  culture in the next pipeline stage for each item and once after the call (a
  cmdlet that does not restore it, or writes an item inside the scope, fails
  both: two mutations proved it), and is proved red on the previous build and
  green on the new one in all four configurations
  (`Tests/ItemCmdlets.Tests.ps1`, `Tests/ObjectApis.Tests.ps1`).

## A test oracle that is wrong on a domain member

- `Get-Acl -Audit` reads the SACL with the other sections and reports an item
  without audit entries as protected (Windows Server 2019, 2022, and 2025
  domain members, Windows 11); the module and `Get-NTFSInheritance` read the
  SACL alone. Tests read the flag with .NET `GetAccessControl(Audit)`
  (`Get-TestAuditAcl`). A suite that is green on the host proves nothing about
  an oracle: run a new test on a domain member before calling it done.

## A piped property and the parameter set

- An object with a property `AppliesTo`, piped into `Add-` or
  `Remove-NTFSAccess` or `-NTFSAudit` with a path, bound the default
  `PathComplex` set and lost the property. Fixed in `93ed2c7`: the four cmdlets
  declare no default set, so the property selects `PathSimple`, an object with
  `AppliesTo` and `InheritanceFlags` fails with `AmbiguousParameterSet`, and the
  tests pipe an object of each shape (red on the previous build, green on the
  new one). A probe that tells the sets uses an entry of the default scope:
  removing `ThisFolderOnly` from it leaves the `InheritOnly` part.
- PowerShell restores only the parameters that the previous piped object
  bound. A field that the cmdlet writes itself stays for the next object: the
  scope that `ProcessRecord` converted from `AppliesTo` into the field behind
  `-InheritanceFlags` went to the next object without a scope. `93ed2c7`
  shipped that, the third review found it (rc7 had it for piped
  `-SecurityDescriptor` objects), and `9783d2a` keeps the flags of a record in
  locals. A pipeline test pipes two or more objects of different shape in one
  call (`Objects with different scopes in one pipeline`, both ParameterSets
  files); one object per call cannot see it.
- Probe the route that the documentation shows. `Import-Csv` of a file gives an
  empty string for a blank cell, `ConvertFrom-Csv` of strings gives `$null` for
  a trailing blank cell, and `Import-Csv` gives `$null` for a column that a row
  lacks. The binder treats them differently: `$null` fails to bind, and a value
  that it cannot convert to the enum (an empty string, a typo) is ignored, so
  the object is handled as one without the property. The first statement and
  the first tests used the convenient route, and the reviewer found the false
  claim; the corrected claim was then too narrow once more (a value that
  converts binds, whatever its form; a flag next to an unusable value wins).
  Write the claim from a probe of each form, not from the one that you tried.
- A sentence that says what a test proves is a claim too: a title that says
  "and change nothing" needs an assertion that can see the change (the audit
  cmdlets write the SACL, not the DACL), and "cannot go red" needs a run.
- The cause was `DefaultParameterSetName = "PathComplex"`: when a piped object
  satisfies the mandatory parameters of the default set, PowerShell settles on
  it and never tries a parameter that belongs to another set. A stand-alone
  model with the four sets and no default binds `PathSimple` for an object with
  `AppliesTo`, `PathComplex` for one without, and an error for one with
  `AppliesTo` and `InheritanceFlags` (`probes\p-parameterset-binding*.ps1` in
  the Handoff 5 evidence; the model binds `PathComplex` for a piped descriptor
  where the real cmdlets bind `SDSimple`); the real cmdlets agreed for paths
  (`probes\p-proto-appliesto.ps1`). The default dated from 4.2.6, when
  `AppliesTo` was optional; `4b1abc9` made it mandatory in the Simple sets, so
  the default no longer decided a named call. Build a model of the parameter
  sets before you change an attribute, and test the real cmdlet afterwards.

## A swallowed initialization error (`catch { }`)

- `Win32.GetEffectiveAccess` ran the start of the authorization manager inside
  an outer `catch { }`. A refusal there gave no exception and no rights, so the
  cmdlet wrote an entry with `Synchronize` only (.NET adds it to every allow
  rule) and no error: a false "no access". The security review of the matrix
  found it (LOW); rc8 fixed it (`25fe775`) with one `try`/`catch` that records
  every exception in `authzException`.
- A trigger without a test seam: `Get-NTFSEffectiveAccess -ServerName ('a' *
  40000)`. `AuthzInitializeRemoteResourceManager` fails with error 14 for a name
  of 32,718 characters or more, and with 1722 (RPC server unavailable, which
  keeps the documented fallback and its warning) for a shorter one. Server
  2019, 2022, 2025, and Windows 11 26H1 agree (a probe in the rc8 record). Bisect
  the length of an input before you add a seam.
- The test accepts both outcomes (an error, or the result of this computer) and
  fails for no access without an error: the red run said `Expected FullControl,
  but got Synchronize`. A system-dependent boundary must not fail the test where
  a system answers like for a short name.
- The review found a second flaw in the same output: the warning "the result is
  based on this computer" came before an error that left no result. A warning
  that qualifies a result belongs with the result (`!FromRemote &&
  !OperationFailed`); the tests assert its absence next to the error.
- A word in the CHANGELOG is a claim: "an overlong name" suggested 256
  characters, where 1722 still falls back. The entry names the probed length.
