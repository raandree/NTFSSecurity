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
                   ├─ NestedModules: NTFSSecurity.dll (36 cmdlets)
                   └─ en-US\NTFSSecurity.dll-Help.xml (Get-Help; generated
                        from Docs/Cmdlets, Decision 8)
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

Each Decision record is a file in `decisions/`; read only the relevant ones.

| # | Decision |
| --- | --- |
| 1 | [Use the canonical Memory Bank base](decisions/0001-canonical-memory-bank.md) |
| 2 | [Cmdlet reference stays platyPS markdown](decisions/0002-platyps-cmdlet-reference.md) |
| 3 | [Document the source at HEAD](decisions/0003-document-source-at-head.md) |
| 4 | [Online help points to GitHub](decisions/0004-online-help-on-github.md) |
| 5 | [Document defects, don't fix them in docs work](decisions/0005-document-defects-separately.md) |
| 6 | [CI checks the docs against a build of the source](decisions/0006-ci-checks-docs-against-build.md) |
| 7 | [CHANGELOG lists user-visible changes only](decisions/0007-changelog-user-visible-only.md) |
| 8 | [Commit the generated help file and check it in CI](decisions/0008-commit-generated-help.md) |

## Patterns

### Verifying documentation

- Run platyPS in Windows PowerShell 5.1 against a module build; a copy of
  `Docs/Cmdlets` must round-trip through `Update-MarkdownHelp` unchanged.
- platyPS rewrites non-ASCII punctuation such as em dashes; keep cmdlet pages
  ASCII-only.
- In cmdlet pages, end a sentence with a link: platyPS renders a link as
  `text (url)` in the help file and drops the space after it.
- Verify examples in a `$env:TEMP` sandbox, never on real data; parse every
  example and check its parameters against `Get-Command` metadata.

### Testing the module

- Pester 5 tests in `Tests/*.Tests.ps1` import
  `NTFSSecurity\bin\Release\NTFSSecurity.psd1` and run in Windows
  PowerShell 5.1 (as in AppVeyor); PowerShell 7 runs are a secondary check.
- `Get-Help -Online` is tested with the internal test hook
  `BypassOnlineHelpRetrieval`, which returns the URI instead of opening a
  browser. In PowerShell 7 the hook also skips the help file, so that test
  runs only in Windows PowerShell; PowerShell 7 resolves the same URI.
- Report Pester 5 results to AppVeyor through the build worker API, not as
  an uploaded NUnit file: the NUnit import files each test under every
  enclosing block (870 entries for 218 tests in build 54834154).
