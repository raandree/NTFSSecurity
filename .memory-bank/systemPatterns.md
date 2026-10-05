---
status: current
last-verified: 2026-10-04
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
                   ├─ RootModule: NTFSSecurity.psm1 (aliases)
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
- `PrivateData` switches: `EnablePrivileges` (base cmdlet), `GetInheritedFrom`
  (`Get-NTFSAccess`, `Get-NTFSAudit`), `GetFileSystemModeProperty` and
  `IdentifyHardLinks` (`Get-ChildItem2`), `ShowAccountSid` (format file).
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
| 9 | [Keep the documentation on GitHub](decisions/0009-docs-on-github.md) |
| 10 | [One version for the manifest, assemblies, and changelog](decisions/0010-one-version.md) |
| 11 | [CI and the wiki run on GitHub Actions](decisions/0011-github-actions.md) |
| 12 | [Releases are built and published by CI on a version tag](decisions/0012-ci-releases.md) |
| 13 | [Set-NTFSInheritance keeps entries like the dedicated cmdlets](decisions/0013-set-inheritance-keeps-entries.md) |

## Patterns

### Verifying documentation

- Run platyPS in Windows PowerShell 5.1 against a module build; a copy of
  `Docs/Cmdlets` must round-trip through `Update-MarkdownHelp` unchanged.
  platyPS rewrites non-ASCII punctuation, so keep cmdlet pages ASCII-only.
  It takes a parameter's `Position` from `Get-Help`, that is from the shipped
  help file: after a position change, edit the page YAML, run
  `New-ExternalHelp`, rebuild, and check the round trip.
- Links: MarkdownLinkCheck checks relative `Docs` links (no anchors),
  `Tests\Wiki.Tests.ps1` the wiki links and anchors; neither covers
  `README.md` and `CHANGELOG.md`. The wiki is generated from `Docs` (never
  edit it); `Docs/README.md` becomes Home, its cmdlet groups the sidebar.
- In cmdlet pages, end a sentence with a link (platyPS drops the space after
  it). Verify examples in a `$env:TEMP` sandbox, never on real data.

### Testing the module

- Pester 5 tests in `Tests/*.Tests.ps1` import
  `NTFSSecurity\bin\Release\NTFSSecurity.psd1`; CI runs every file of
  `Tests` in Windows PowerShell 5.1 and in PowerShell 7 (Decision 11) with
  `.github/scripts/Invoke-Tests.ps1` (job summary, NUnit `test-results`).
- A test that changes files, links, or security descriptors uses
  `Tests\TestHelpers.psm1`: its own sandbox below
  `$env:TEMP\NTFSSecurity.Tests`, `Assert-TestSandboxPath` before each
  change, `Remove-TestSandbox` (links first, then ACL reset). Cases that need
  a privilege skip with `Test-PrivilegeHeld` and run in CI (elevated);
  `Block-TestReadPermission` (OWNER RIGHTS deny) makes a read fail without
  elevation.
- `Get-Help -Online` tests use the internal hook `BypassOnlineHelpRetrieval`,
  which PowerShell 7 ignores for the help file: 36 tests run only in Windows
  PowerShell.
- `Manifest.Tests.ps1`: `Test-ModuleManifest` clean, exactly 36 cmdlets, one
  version in manifest and assemblies (Decision 10). `Release.Tests.ps1`:
  release notes for the manifest version, and the packages (`FileList`
  files, version with label, command tags, zip layout).
