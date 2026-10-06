---
status: current
last-verified: 2026-10-05
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

- `BaseCmdlet` resolves only relative paths, against the current file
  system location of the session (not `$PWD`, #86). Path parameters carry
  `[FileSystemPathTransformation]`, which binds file objects as full paths.
- On access denied, most cmdlets retry through `InvokeAsOwner`, which takes
  ownership and restores the previous owner on every exit path.
- `BaseCmdletWithPrivControl` enables Backup, Restore, TakeOwnership, and
  Security in `BeginProcessing` when `PrivateData.EnablePrivileges` is
  `$true`, and disables the ones it enabled in `EndProcessing`.
- `PrivateData` switches: `EnablePrivileges`, `GetInheritedFrom`,
  `GetFileSystemModeProperty`, `IdentifyHardLinks`, `ShowAccountSid`.
- Cmdlets accept `-Path` (alias `FullName`) or `-SecurityDescriptor`; the
  SD sets change the object in memory until `Set-NTFSSecurityDescriptor`.

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
| 14 | [Repository hardening is optional](decisions/0014-repository-hardening-optional.md) |
| 15 | [Merge stacked pull requests in order with merge commits](decisions/0015-merge-stacks-with-merge-commits.md) |
| 16 | [Fix only reproducible bugs](decisions/0016-fix-reproducible-bugs-only.md) |
| 17 | [Issue labels](decisions/0017-issue-labels.md) |

## Patterns

### Verifying documentation

- Run platyPS in Windows PowerShell 5.1 against a Release build; a copy of
  `Docs/Cmdlets` must round-trip through `Update-MarkdownHelp` unchanged.
  Keep cmdlet pages ASCII-only. platyPS takes `Position` and `Required` from
  the shipped help file: after such a change, edit the page YAML, run
  `New-ExternalHelp`, rebuild, and check the round trip.
- MarkdownLinkCheck checks relative `Docs` links, `Tests\Wiki.Tests.ps1`
  the wiki links and anchors. The wiki is generated from `Docs` (never edit
  it); `Docs/README.md` becomes Home, its cmdlet groups the sidebar.
- In cmdlet pages, end a sentence with a link (platyPS drops the space
  after it). Verify examples in a `$env:TEMP` sandbox, never on real data.

### Testing the module

- Pester 5 tests in `Tests/*.Tests.ps1` import the Release build; CI runs
  them in Windows PowerShell 5.1 and PowerShell 7 (Decision 11).
- A test that changes files, links, or security descriptors uses
  `Tests\TestHelpers.psm1`: its own sandbox, `Assert-TestSandboxPath`
  before each change, `Remove-TestSandbox`. Cases that need a privilege
  skip with `Test-PrivilegeHeld` and run in CI (elevated);
  `Block-TestReadPermission` and `Block-TestWritePermission` make a read or
  a write fail without elevation.
- `Get-Help -Online` tests run only in Windows PowerShell, which honors the
  hook `BypassOnlineHelpRetrieval`. `Manifest.Tests.ps1` and
  `Release.Tests.ps1` check the manifest, the version (Decision 10), the
  release notes, and the packages.
