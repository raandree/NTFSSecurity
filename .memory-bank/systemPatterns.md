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
| 9 | [Keep the documentation on GitHub](decisions/0009-docs-on-github.md) |
| 10 | [One version for the manifest, assemblies, and changelog](decisions/0010-one-version.md) |
| 11 | [CI and the wiki run on GitHub Actions](decisions/0011-github-actions.md) |
| 12 | [Releases are built and published by CI on a version tag](decisions/0012-ci-releases.md) |

## Patterns

### Verifying documentation

- Run platyPS in Windows PowerShell 5.1 against a module build; a copy of
  `Docs/Cmdlets` must round-trip through `Update-MarkdownHelp` unchanged.
- GitHub renders the docs (Decision 9), and CI publishes them to the wiki
  (Decision 11). The MarkdownLinkCheck step covers only relative links in
  `Docs` and ignores anchors; `Tests\Wiki.Tests.ps1` checks every link of
  the generated wiki, including anchors (GitHub's slug rules: lowercase,
  punctuation removed, spaces to hyphens). Check the links in `README.md`
  and `CHANGELOG.md` separately.
- The wiki is generated: edit `Docs`, never the wiki.
  `Export-WikiContent.ps1` names a page after its file (`Docs/README.md`
  becomes Home), rewrites links, and builds the sidebar from the cmdlet
  groups of `Docs/README.md`; a cmdlet missing there fails `Wiki.Tests.ps1`.
- platyPS rewrites non-ASCII punctuation such as em dashes; keep cmdlet pages
  ASCII-only.
- In cmdlet pages, end a sentence with a link: platyPS renders a link as
  `text (url)` in the help file and drops the space after it.
- Verify examples in a `$env:TEMP` sandbox, never on real data; parse every
  example and check its parameters against `Get-Command` metadata.

### Testing the module

- Pester 5 tests in `Tests/*.Tests.ps1` import
  `NTFSSecurity\bin\Release\NTFSSecurity.psd1`; CI runs them in Windows
  PowerShell 5.1 and in PowerShell 7 (Decision 11).
- `Get-Help -Online` is tested with the internal test hook
  `BypassOnlineHelpRetrieval`, which returns the URI instead of opening a
  browser. In PowerShell 7 the hook also skips the help file, so that test
  runs only in Windows PowerShell (36 skipped tests in PowerShell 7);
  PowerShell 7 resolves the same URI.
- `.github/scripts/Invoke-Tests.ps1` runs Pester for CI: the counts and the
  failed tests go to the job summary, the NUnit file to the `test-results`
  artifact, and it fails on failed test files too (`Result -ne 'Passed'`).
- `Tests\Manifest.Tests.ps1` checks the built manifest: `Test-ModuleManifest`
  without errors or warnings, exactly 36 cmdlets, and the same version in
  the manifest and the assemblies (Decision 10). Add a new cmdlet to
  `CmdletsToExport` and to the expected count in the same change.
- `Tests\Release.Tests.ps1` checks that `CHANGELOG.md` has release notes
  for the manifest version (dated section, or `[Unreleased]` for a
  prerelease) and the packages: only `FileList` files, version with label,
  command tags, and `NTFSSecurity.zip` with the module folder.
