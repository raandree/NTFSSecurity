---
status: current
last-verified: 2026-10-02
owner: active-agent
source: repository evidence
---

# Progress

## Current status

PR #91 is merged: documentation matches the cmdlets at HEAD. The module
source is unchanged since the 4.2.6 release except the
`Remove-Item2 -PassThru` rename and `CompatiblePSEditions`.

## Recent milestones

- 2026-10-02: Memory Bank initialized.
- 2026-10-02: Documentation aligned with the code: 36 cmdlet pages filled
  from the C# source and checked at runtime in a sandbox; Concepts, Examples,
  home page, contributor guide, README rewritten; `mkdocs.yml` nav,
  `edit_uri`, and `.readthedocs.yml` (`build.os`) fixed; `CHANGELOG.md`
  created.
- 2026-10-02: PR #91 build fixed: `appveyor.yml` builds the module from
  source and checks the docs against that build instead of the Gallery
  release (root cause of the `Remove-Item2 -PassThru` drift failure).
- 2026-10-02: PR #91 merged into `master` as `690d8dd` (squash merge);
  branch `ai/docs-alignment` deleted locally and on GitHub.
- 2026-10-02: Work package 1 (housekeeping, `ai/housekeeping`): local
  `promptHistory.md` ignored by git; changelog policy recorded as
  Decision 7; Decisions moved from `systemPatterns.md` to `decisions/`.

## Stable capabilities

- 36 cmdlets: access (7), audit (5), inheritance (6), owner and security
  descriptor (4), privileges (3), long-path items (6), links, hash, and
  disk space (5).
- Works in Windows PowerShell 5.1 and PowerShell 7 (smoke-tested), except
  `Get-FileHash2`, which fails in PowerShell 7 (missing `RIPEMD160` type).

## Open work

Work packages in the order agreed with the maintainer. Each gets one
`ai/<slug>` branch and PR, committed locally; the maintainer pushes, and
the next package starts only after the maintainer's go-ahead.

1. Housekeeping: committed on `ai/housekeeping`; awaiting push and PR.
2. Ship help: generate `en-US\NTFSSecurity.dll-Help.xml` from `Docs/Cmdlets`
   with `New-ExternalHelp` and ship it (csproj `Content`, manifest
   `FileList`); remove the stale `NTFSSecurity-Help.xml` and, if unused,
   `NTFSSecurity\Help\NTFSSecurity.Help.pshproj`. Ask the maintainer:
   commit the file plus a CI currency check, or generate it in the build.
3. Read the Docs: project `ntfssecurity` (maintainer `Sup3rlativ3`) builds
   the fork; switch it to this repository or import a new project. Ask
   before installing Python for `mkdocs build --strict`.
4. Manifest and version: remove `Show-NTFSSimpleAccess` and the duplicate
   inheritance entries from `CmdletsToExport` (36 cmdlets remain); ask
   about the next version (with or without a `PassThur` alias),
   `PowerShellVersion`, and `DotNetFrameworkVersion`; align `AssemblyInfo`.
   No tag or publish.
5. Code defects, listed below: `review: on`, one PR per group, regression
   test first. Pester 5 tests import `NTFSSecurity\bin\Release`, run in a
   `$env:TEMP` sandbox and in `appveyor.yml`, and skip elevated cases when
   not elevated. Each fix updates its cmdlet page and `CHANGELOG.md`.

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
