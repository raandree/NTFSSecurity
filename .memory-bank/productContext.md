---
status: current
last-verified: 2026-10-02
owner: shared
source: repository evidence
---

# Product context

## Problem

PowerShell ships only `Get-Acl` and `Set-Acl`; everything between reading
and writing an ACL (permission reports, adding or removing one entry,
inheritance, ownership, orphaned SIDs) needs custom .NET code. The module
provides task-level cmdlets for these jobs (`README.md` summary).

## Users

- People who manage NTFS file and folder permissions with PowerShell
  (README summary). Specific personas: To confirm.

## Core workflows

1. Report permissions: `Get-NTFSAccess`, `Get-NTFSSimpleAccess`,
   `Get-NTFSEffectiveAccess`.
2. Change permissions: `Add-NTFSAccess`, `Remove-NTFSAccess`,
   `Clear-NTFSAccess`; the audit equivalents manage the SACL.
3. Back up and restore explicit permissions through CSV
   (`Get-NTFSAccess | Export-Csv`, `Import-Csv | Add-NTFSAccess`).
4. Find and remove orphaned entries: `Get-NTFSOrphanedAccess`.
5. Repair inheritance and ownership: `*-NTFSAccessInheritance`,
   `Set-NTFSInheritance`, `Set-NTFSOwner`, using backup/restore privileges.
6. Work with paths longer than 260 characters: `Get-ChildItem2` and the other
   `*-Item2` cmdlets.

## Experience goals

- Pipeline first: item cmdlets emit objects whose `FullName` binds to `-Path`.
- Accept account names and SIDs; output shows both when resolvable.
- Output formatted like `Get-ChildItem` (`NTFSSecurity.format.ps1xml`).
- Work on files the caller cannot normally open by enabling the Backup,
  Restore, TakeOwnership, and Security privileges automatically.
