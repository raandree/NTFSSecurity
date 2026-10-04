---
status: current
last-verified: 2026-10-04
owner: active-agent
source: repository evidence
---

# Progress

## Current status

PRs #91 to #98 are merged. CI published the prerelease 5.0.0-rc1 from
`master` (`e0f5366`, tag `5.0.0-rc1`) to the PowerShell Gallery and GitHub;
the stable Gallery version is still 4.2.6. CI runs on GitHub Actions:
build, docs checks, tests in Windows PowerShell 5.1 and PowerShell 7,
packages, the wiki generated from `Docs` (43 pages), and releases on a
version tag (Decision 12). Next: the maintainer tests 5.0.0-rc1.

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
- 2026-10-04: Work packages 3 (#94, `bde59a5`), 4 (#95, `6665825`), and the
  move to GitHub Actions (#96, `4f9f7cc`) merged with merge commits: Read
  the Docs dropped (Decision 9), version 5.0.0 with a valid manifest
  (Decision 10), CI and a wiki generated from `Docs` on GitHub Actions
  (Decision 11). The first `master` run (37218869672) passed and published
  the wiki (`62ec94a`, 43 pages).
- 2026-10-04: The maintainer kept the version history separate from
  `CHANGELOG.md` and had it completed from the six PowerShell Gallery
  packages and the commit history (#97, `59663c9`): release dates, notes
  for 4.2.2, detailed notes for 4.2.4, and separate notes for 4.2.5 and
  4.2.6. The wiki republished it.
- 2026-10-04: The maintainer chose to release 5.0.0 next, through CI and a
  prerelease first (Decision 12): `ai/release-5.0.0` adds the `release` job,
  `Get-ReleaseInfo.ps1`, `New-ModulePackage.ps1`, `Tests\Release.Tests.ps1`,
  the label `rc1`, and `Docs/Contributing/05-Releasing.md`. The package
  dry run found that PSResourceGet drops the command tags that 4.2.6 had;
  the script adds them back.
- 2026-10-04: #98 merged (`e0f5366`); the tag `5.0.0-rc1` ran the release
  job (run 37230802387), which published to the Gallery at 20:12 UTC and
  created the GitHub prerelease. Verified: the Gallery nupkg is
  byte-identical to the CI artifact, the GitHub zip to the CI zip; the DLLs
  are optimized Release builds; the Gallery shows the prerelease flag, the
  release notes link, and 85 tags (36 `PSCmdlet_`, 36 `PSCommand_`,
  `PSIncludes_Cmdlet`, plus `PSEdition_Core` and `PSEdition_Desktop`, which
  the Gallery adds itself); stable search still returns 4.2.6. Installed
  with `Save-PSResource`, the module passes the full suite (Windows
  PowerShell 261 passed and 7 skipped, PowerShell 7 232 passed and 36
  skipped). The command search still returned 4.2.6 minutes after
  publishing, because the search index lagged.

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
3. Docs on GitHub: done (#94).
4. Manifest and version 5.0.0: done (#95).
4b. CI and the wiki on GitHub Actions: done (#96). Left to the maintainer:
   revoke AppVeyor's GitHub access if it is still granted, consider
   **Restrict editing to collaborators only** for the wiki, and optionally
   ask `Sup3rlativ3` to delete the Read the Docs project.
4c. Version history from the PowerShell Gallery: done (#97).
4d. Release 5.0.0 through CI (Decision 12): 5.0.0-rc1 published and
   verified (#98). Next: the maintainer tests the prerelease; recheck
   `Find-PSResource -CommandName Get-NTFSAccess -Prerelease`, which should
   list 5.0.0-rc1 once the Gallery index catches up. For the final release:
   remove the label, rename `[Unreleased]` to `[5.0.0]` with the date, and
   tag `5.0.0` (steps in `Docs/Contributing/05-Releasing.md`). Consider
   changing the manifest `Description`, which says "Windows PowerShell
   Module", before the final release. Releases no longer come from a local
   build, so the old manual steps (cleaning
   `C:\Program Files\WindowsPowerShell\Modules\NTFSSecurity`, Debug
   builds) no longer apply.
5. Code defects, listed below: `review: on`, one PR per group, regression
   test first. Pester 5 tests import `NTFSSecurity\bin\Release`, run in a
   `$env:TEMP` sandbox and in the CI workflow (pattern:
   `Tests\Help.Tests.ps1`), and skip elevated cases when not elevated;
   check whether the GitHub Actions Windows runner runs elevated. Each fix
   updates its cmdlet page and `CHANGELOG.md`.

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
