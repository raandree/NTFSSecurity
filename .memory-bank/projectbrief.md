---
status: current
last-verified: 2026-10-02
owner: shared
source: repository evidence
---

# Project brief

## Purpose

NTFSSecurity is a binary (C#) PowerShell module that fills the gap between
`Get-Acl` and `Set-Acl`: cmdlets to read, add, remove, and clear NTFS
permissions (DACL) and audit rules (SACL), manage inheritance and ownership,
copy security descriptors, control process privileges, and work with long
paths (`*-Item2` cmdlets via AlphaFS), hard links, and symbolic links.
Source: `README.md`, `NTFSSecurity/NTFSSecurity.psd1`.

## Scope

- In scope: module source (`NTFSSecurity`, `Security2`, `PrivilegeControl`,
  `ProcessPrivileges`), module manifest and type/format data, the MkDocs
  documentation site in `Docs/`, and `README.md`.
- Out of scope: registry security. `Security2/Registry/RegistrySecurity.cs`
  exists, but no registry cmdlet is exported.
- Distribution: PowerShell Gallery package `NTFSSecurity` and GitHub releases.

## Stakeholders

- Maintainer and author: Raimund Andree (`raandree`), per the manifest.
- Documentation contributors: James Smith (`mkdocs.yml` `site_author`);
  the AppVeyor documentation build runs under the `Sup3rlativ3` account.
- End users: To confirm beyond the README summary.

## Acceptance criteria

1. Every exported cmdlet has an accurate platyPS page in `Docs/Cmdlets`.
2. `Update-MarkdownHelp` against the module produces no parameter drift
   (the check in `appveyor.yml`).
3. The module imports in Windows PowerShell 5.1 and PowerShell 7
   (`CompatiblePSEditions = 'Core', 'Desktop'`).
4. Further release criteria: To confirm.
