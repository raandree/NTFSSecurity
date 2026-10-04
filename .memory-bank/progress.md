---
status: current
last-verified: 2026-10-02
owner: active-agent
source: repository evidence
---

# Progress

## Current status

PRs #91, #92, and #93 are merged. The documentation matches the cmdlets at
`master`, and the module ships the help file generated from it
(`en-US\NTFSSecurity.dll-Help.xml`). Otherwise the module source differs
from the 4.2.6 release only by the `Remove-Item2 -PassThru` rename and
`CompatiblePSEditions`.

## Recent milestones

- 2026-10-02: Memory Bank initialized. PR #91 aligned the documentation
  with the code (36 cmdlet pages, conceptual pages, README, `mkdocs.yml`,
  `.readthedocs.yml`, `CHANGELOG.md`) and made `appveyor.yml` build the
  module and check the docs against that build (Decision 6); squash-merged
  as `690d8dd`.
- 2026-10-02: PR #83 (TechNet links) closed by the maintainer as superseded
  by #91.
- 2026-10-04: Work package 1 merged as PR #92 with a merge commit
  (`d917832`): `promptHistory.md` ignored, Decision 7, Decisions moved to
  `decisions/`.
- 2026-10-04: Work package 2 squash-merged as PR #93 (`14799fb`): generated
  help file shipped (Decision 8), stale help files removed, `FileList`
  complete, `Tests\Help.Tests.ps1` (218 Pester tests), CI steps 03 (help
  file current) and 04 (Pester, one Tests-tab entry per test; the NUnit
  upload had listed 870), six cmdlet-page links reworded for the help
  text. AppVeyor passed 218 of 218 on the PR (54834295) and on `master`
  (54834350).

## Stable capabilities

- 36 cmdlets: access (7), audit (5), inheritance (6), owner and security
  descriptor (4), privileges (3), long-path items (6), links, hash, and
  disk space (5).
- Works in Windows PowerShell 5.1 and PowerShell 7 (smoke-tested), except
  `Get-FileHash2`, which fails in PowerShell 7 (missing `RIPEMD160` type).

## Open work

Work packages in the order agreed with the maintainer. Each gets one
`ai/<slug>` branch and PR, committed locally. The maintainer pushes and
opens the PR (the agent can't; see `techContext.md`, Constraints), and the
next package starts only after the maintainer's go-ahead.

1. Housekeeping: done (#92).
2. Ship help: done (#93).
3. Read the Docs, next. The local branch `ai/read-the-docs` exists and so
   far carries Memory Bank notes only. The project `ntfssecurity`
   (`https://app.readthedocs.org/projects/ntfssecurity/`) is maintained by
   GitHub user `Sup3rlativ3` and builds the fork `Sup3rlativ3/NTFSSecurity`
   (last build about 2021); the repository side is ready
   (`.readthedocs.yml`, `Docs/requirements.txt`). The switch happens in the
   Read the Docs dashboard. Give the maintainer exact steps for both
   options: (a) `Sup3rlativ3` adds him as maintainer and changes the
   repository URL, or (b) he imports `raandree/NTFSSecurity` as a new
   project (the slug `ntfssecurity` is taken). Ask before installing Python
   for `mkdocs build --strict`. After the switch, confirm a build of
   `master`, propose whether the `online version` links move to Read the
   Docs (Decision 4), and add a documentation link to `README.md`. Done
   when Read the Docs builds `master` of this repository and shows the
   current pages.
4. Manifest and version: remove `Show-NTFSSimpleAccess` and the duplicate
   inheritance entries from `CmdletsToExport` (exactly 36 cmdlets
   exported). Versions disagree: manifest 4.2.5, tag and Gallery 4.2.6,
   `AssemblyVersion` 4.2.1.0. Propose the next SemVer version with and
   without `[Alias('PassThur')]` on `Remove-Item2 -PassThru` (the rename in
   #64 is breaking), plus `PowerShellVersion` and `DotNetFrameworkVersion`
   (manifest 2.0 and 3.5; the assemblies target .NET Framework 4.5.2), and
   ask. Move the `[Unreleased]` entries into the new version section (ask
   whether the build-only "Read the Docs build configuration" entry stays,
   Decision 7) and align `AssemblyInfo`. No tag or publish. Done when
   `Test-ModuleManifest` passes, 36 cmdlets are exported, and CI is green.
   Inputs: `Test-ModuleManifest` already fails on
   `PowerShellVersion = '2.0'` with `CompatiblePSEditions`; releases are
   Debug builds published with the whole output folder (`.pdb`, `.xml`,
   `System.Management.Automation.dll`), which `FileList` doesn't list.
   Before the next build and `Publish-Module`, clean
   `C:\Program Files\WindowsPowerShell\Modules\NTFSSecurity`, or the removed
   `NTFSSecurity-Help.xml` ships again.
5. Code defects, listed below: `review: on`, one PR per group, regression
   test first. Pester 5 tests import `NTFSSecurity\bin\Release`, run in a
   `$env:TEMP` sandbox and in `appveyor.yml` (pattern:
   `Tests\Help.Tests.ps1`), and skip elevated cases when not elevated;
   check whether AppVeyor runs elevated. Each fix updates its cmdlet page
   and `CHANGELOG.md`.

### Code defects (work package 5)

Numbered as agreed with the maintainer; each is documented on its page.

#### A: Crashes and wrong results

- (1) `Set-NTFSInheritance` reads an unset `Nullable<bool>` when
  `-AccessInheritanceEnabled` is omitted; omitted should mean unchanged.
- (2) `Get-ChildItem2` casts a file `-Path` to `DirectoryInfo`
  (`InvalidCastException`).
- (3) `Get-FileHash2` returns at a folder in `-Path` and skips the rest.
- (4) `Get-NTFSAudit` re-emits the previous item's entries after a failed
  path, and returns nothing without the Security privilege instead of an
  error.
- (5) `Add-NTFSAudit`: `-Account` and `-AccessRights` share position 2;
  use 2 and 3 like `Remove-NTFSAudit`.
- (6) `-PassThru` returns access entries in `Add-NTFSAudit` SD sets and
  `Remove-NTFSAudit` Path sets.
- (7) `FileSystemAuditRule2.GetFileSystemAuditRules` takes
  `InheritanceEnabled` from `AreAccessRulesProtected`.
- (8) `Get-NTFSInheritance -SecurityDescriptor` reports
  `AuditInheritanceEnabled = $true` without a SACL (Path set: `$null`).
- (9) `Get-NTFSOwner`: the access-denied retry repeats the failing call,
  and the catch-all turns `PipelineStoppedException` into
  `ReadSecurityError`.
- (10) `Copy-Item2` fails on a folder with files
  (`DirectoryNotFoundException`).
- (11) `Disable-Privileges` hits a null `privileges` field when
  `EnablePrivileges = $false`.
- (12) The six inheritance cmdlets enable privileges unconditionally in
  `BeginProcessing` and leave them enabled.
- (13) Format view `Children2`: the `Inherits` column uses
  `IsInheritanceBlocked`, so it always shows `True` for `Get-ChildItem2`.

#### B: Ignored parameters and parameter sets

- (14) SD sets of `Add-/Remove-NTFSAccess` and `Add-/Remove-NTFSAudit`
  cannot resolve without `-AppliesTo` or the flag parameters.
- (15) `Get-NTFSEffectiveAccess`: `-ExcludeNoneAccessEntries` has no
  effect, there is no output without `-Path`, and the SD set returns
  nothing.
- (16) `Get-NTFSOrphanedAccess`, `Get-NTFSOrphanedAudit`, and
  `Get-NTFSSimpleAccess` ignore `-Account` and `-SecurityDescriptor`;
  `Get-NTFSOrphanedAudit` writes collections; `SimpleFileSystemAccessRule`
  has no format view.
- (17) `removeSpecific` in `Remove-NTFSAccess/Audit` is never bound;
  `Remove-NTFSAudit` leaves `appliesTo` uninitialized.

#### C: Error handling

- (18) `Copy-Item2`, `Move-Item2`, `Remove-Item2`: one failing path skips
  the rest of `-Path` (`return` instead of `continue`).
- (19) `Remove-NTFSAccess` continues after a failed read and writes a
  second, misleading `RemoveAceError`.
- (20) The inheritance cmdlets write `-PassThru` output in `finally`, even
  after a failure.
- (21) `New-NTFSHardLink` says the target path exists when it doesn't.

#### D: Metadata and cosmetics

- (22) Wrong or missing `[OutputType]` (`Test-Path2`, `Get-FileHash2`,
  `Add-NTFSAudit`, `*-Item2`, inheritance cmdlets);
  `Enable-/Disable-Privileges -PassThru` writes one collection;
  `New-NTFSSymbolicLink -PassThru` returns `FileInfo` for folder links.
- (23) Typos: "Privliege" in the `Get-NTFSEffectiveAccess` warning; "are
  now enabled" in the `Disable-Privileges` verbose message.
- (24) Dead code in `RemoveItem2.cs` and `OtherCmdlets.cs`.

#### E: Maintainer decisions before changing behavior

- `Clear-NTFSAccess -DisableInheritance` discards inherited entries: keep
  that, or copy them?
- `Set-NTFSInheritance` defaults are the opposite of the dedicated
  inheritance cmdlets: align?
- The audit inheritance switches are named `*AccessRules`: add
  `*AuditRules` aliases?
- `Get-FileHash2` fails in PowerShell 7 (`RIPEMD160`): drop the algorithm
  there, load it lazily, or deprecate the cmdlet?
