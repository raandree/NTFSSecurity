---
status: current
last-verified: 2026-10-02
owner: active-agent
source: repository evidence
---

# Progress

## Current status

Documentation matches the cmdlets at HEAD. The module source is unchanged
since the 4.2.6 release except the `Remove-Item2 -PassThru` rename and
`CompatiblePSEditions`.

## Recent milestones

- 2026-10-02: Memory Bank initialized.
- 2026-10-02: Documentation aligned with the code: 36 cmdlet pages filled
  from the C# source and checked at runtime in a sandbox; Concepts, Examples,
  home page, contributor guide, README rewritten; `mkdocs.yml` nav,
  `edit_uri`, and `.readthedocs.yml` (`build.os`) fixed; `CHANGELOG.md`
  created.

## Stable capabilities

- 36 cmdlets: access (7), audit (5), inheritance (6), owner and security
  descriptor (4), privileges (3), long-path items (6), links, hash, and
  disk space (5).
- Works in Windows PowerShell 5.1 and PowerShell 7 (smoke-tested), except
  `Get-FileHash2`, which fails in PowerShell 7 (missing `RIPEMD160` type).

## Open work

- Ship help: add the generated `en-US\NTFSSecurity.dll-Help.xml` to the
  build and drop the stale `NTFSSecurity-Help.xml`.
- Publishing: re-point Read the Docs and AppVeyor from the fork
  `Sup3rlativ3/NTFSSecurity`; `appveyor.yml` checks docs against the Gallery
  module instead of the source.
- Manifest: remove `Show-NTFSSimpleAccess` and duplicates from
  `CmdletsToExport`; bump `ModuleVersion` (4.2.5 in source, 4.2.6 released).
- Code defects found while documenting (each documented on its page):
  `Add-NTFSAudit` duplicate position 2; SD parameter sets of
  `Add/Remove-NTFSAccess/Audit` need `-AppliesTo`; `Set-NTFSInheritance`
  nullable crash and hard-coded removal; inheritance cmdlets ignore
  `EnablePrivileges = $false`; `Get-NTFSEffectiveAccess`
  `-ExcludeNoneAccessEntries` and SD set ineffective; `-Account`/SD ignored by
  `Get-NTFSOrphanedAccess/Audit` and `Get-NTFSSimpleAccess`; `Copy-Item2`
  fails on folders with files; `Get-ChildItem2` throws on a file path;
  `return` instead of `continue` in several `ProcessRecord` loops; wrong
  `OutputType` on several cmdlets; `Get-FileHash2` in PowerShell 7.
