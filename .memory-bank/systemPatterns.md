---
status: current
last-verified: 2026-10-02
owner: active-agent
source: repository evidence
---

# System patterns

## Architecture

```text
NTFSSecurity.psd1 ─┬─ ScriptsToProcess: NTFSSecurity.Init.ps1
                   │    Add-Type: Security2.dll, PrivilegeControl.dll,
                   │    ProcessPrivileges.dll, inline NTFS.DriveInfoExt;
                   │    Update-FormatData -PrependPath format.ps1xml
                   ├─ TypesToProcess: NTFSSecurity.types.ps1xml
                   │    (Owner, IsInheritanceBlocked, LengthOnDisk on
                   │    FileInfo/DirectoryInfo; AccountType on ACEs)
                   ├─ ModuleToProcess: NTFSSecurity.psm1 (aliases)
                   └─ NestedModules: NTFSSecurity.dll (36 cmdlets)
NTFSSecurity.dll ── cmdlets ──> Security2.dll (FileSystemAccessRule2,
                                FileSystemAuditRule2, IdentityReference2,
                                FileSystemInheritanceInfo, EffectiveAccess)
                 ── long paths ──> AlphaFS
                 ── privileges ──> PrivilegeControl / ProcessPrivileges
```

- `BaseCmdlet` resolves relative paths against `$PWD`.
- `BaseCmdletWithPrivControl` (access, audit, inheritance, owner, security
  descriptor, and privilege cmdlets) enables Backup, Restore, TakeOwnership,
  and Security in `BeginProcessing` when `PrivateData.EnablePrivileges` is
  `$true`, and disables the ones it enabled in `EndProcessing`.
- `PrivateData` switches: `EnablePrivileges` (base cmdlet),
  `GetInheritedFrom` (`Get-NTFSAccess`, `Get-NTFSAudit`),
  `GetFileSystemModeProperty` and `IdentifyHardLinks` (`Get-ChildItem2`),
  `ShowAccountSid` (format file).
- Cmdlets accept either `-Path` (alias `FullName`) or `-SecurityDescriptor`
  (from `Get-NTFSSecurityDescriptor`); SD sets change the in-memory object
  until `Set-NTFSSecurityDescriptor` writes it back.

## Decisions

### Decision 1: Use the canonical Memory Bank base

- Choice: Keep durable project context in .memory-bank.
- Rationale: Preserve evidence-backed context across sessions.

### Decision 2: Cmdlet reference stays platyPS markdown

- Choice: `Docs/Cmdlets/*.md` keep the platyPS 0.14 schema 2.0.0 layout
  (upper-case section headings, YAML parameter blocks, one paragraph per
  line) so `Update-MarkdownHelp` and `New-ExternalHelp` round-trip.
- Rationale: `appveyor.yml` checks the pages with `Update-MarkdownHelp`;
  the same files can generate MAML help.

### Decision 3: Document the source at HEAD

- Choice: Docs describe the code on `master`. Where HEAD differs from the
  latest Gallery release, the page says which version changed.
- Rationale: The user asked to align docs with the actual code; the only
  current difference is `Remove-Item2 -PassThru` (4.2.6 spells `-PassThur`).

### Decision 4: Online help points to GitHub

- Choice: `online version` of every cmdlet page is
  `https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/<Name>.md`.
- Rationale: The Read the Docs project builds a stale fork, so its URLs show
  outdated pages; GitHub always shows `master`.

### Decision 5: Document defects, don't fix them in docs work

- Choice: Code defects found while documenting are described on the affected
  page (workaround or limitation) and listed in `progress.md`; source code is
  changed only in separate, tested work.
- Rationale: No build toolchain was available to verify code changes, and
  the docs must describe current behavior.

### Pattern: verifying documentation

- Run platyPS in Windows PowerShell 5.1 against a module build; a copy of
  `Docs/Cmdlets` must round-trip through `Update-MarkdownHelp` unchanged.
- platyPS rewrites non-ASCII punctuation such as em dashes; keep cmdlet pages
  ASCII-only.
- Verify examples in a `$env:TEMP` sandbox, never on real data; parse every
  example and check its parameters against `Get-Command` metadata.
