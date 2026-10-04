---
status: current
last-verified: 2026-10-04
owner: active-agent
source: repository evidence
---

# Progress

## Current status

PRs #91, #92, and #93 are merged. The documentation matches the cmdlets at
`master`, and the module ships the help file generated from it
(`en-US\NTFSSecurity.dll-Help.xml`). Otherwise the module source differs
from the 4.2.6 release only by the `Remove-Item2 -PassThru` rename and
`CompatiblePSEditions`. Work packages 3 (`ai/docs-on-github`) and 4
(`ai/manifest-version`, stacked on 3) are PR-ready locally.

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
- 2026-10-04: The maintainer dropped Read the Docs: the docs stay on GitHub
  and the wiki is retired (Decision 9). Work package 3 committed locally on
  `ai/docs-on-github` (`84328dc`). The strict Read the Docs build prepared
  before stays unmerged on the local branch `ai/read-the-docs`.
- 2026-10-04: Work package 4 committed locally on `ai/manifest-version`
  (`678ff90`), stacked on `ai/docs-on-github`: valid manifest (requires
  PowerShell 5.1), 36 cmdlets, version 5.0.0 everywhere (Decision 10),
  `-PassThur` alias. The AppVeyor test script, run locally in Windows
  PowerShell 5.1, passed: no docs drift, 0 broken links, current help file,
  228 of 228 Pester tests. `Test-ModuleManifest` passes in Windows
  PowerShell 5.1 and PowerShell 7.6.1.

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
3. Docs on GitHub (was: Read the Docs), PR-ready on `ai/docs-on-github`:
   Read the Docs and MkDocs configuration removed, `Docs/index.md` renamed
   to `Docs/README.md`, the wiki's version history and install steps moved
   into `Docs` (with reconstructed notes for 4.2.5 and 4.2.6), contributor
   guide updated. After the merge, the maintainer turns the wiki off, points
   the notes of releases 4.2.4 and 4.2.6 to `Docs/Version-History.md`, and
   may ask `Sup3rlativ3` to delete the Read the Docs project.
4. Manifest and version, PR-ready on `ai/manifest-version`, stacked on
   `ai/docs-on-github` (merge that PR first with a merge commit).
   Maintainer decisions: `PowerShellVersion` 5.1, `DotNetFrameworkVersion`
   4.5.2, `RootModule`; version 5.0.0; `[Alias('PassThur')]` on
   `Remove-Item2 -PassThru`, listed under Deprecated; `NTFSSecurity`,
   `Security2`, and `PrivilegeControl` carry the module version (Decision
   10). Before the release, not part of the PR: set the date of the 5.0.0
   section to the release date, tag `5.0.0` (no `v` prefix), build in
   Release, and clean `C:\Program Files\WindowsPowerShell\Modules\NTFSSecurity`
   before `Publish-Module`; releases so far were Debug builds published with
   the whole output folder (`.pdb`, `.xml`,
   `System.Management.Automation.dll`), and the removed
   `NTFSSecurity-Help.xml` would ship again.
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
