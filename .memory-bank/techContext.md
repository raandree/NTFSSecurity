---
status: current
last-verified: 2026-10-02
owner: active-agent
source: repository evidence
---

# Tech context

## Stack

- C# class libraries, old-style `.csproj`, .NET Framework 4.5.2,
  solution `NTFSSecurity.sln` (Visual Studio 2017 format).
- Projects: `NTFSSecurity` (cmdlets), `Security2` (ACL object model, Win32
  interop), `PrivilegeControl` and `ProcessPrivileges` (token privileges),
  `Log`, `TestClient`, `NTFSSecurityTest` (MSTest, minimal coverage).
- NuGet (`packages.config`): AlphaFS 2.2.x for long paths;
  `System.Management.Automation.dll` 10.0.10586.0.
- Module: `NTFSSecurity.psd1` loads `NTFSSecurity.psm1` (aliases `dir2`,
  `gi2`, `rm2`, `del2`), `NTFSSecurity.Init.ps1` (Add-Type of the helper
  assemblies, prepends `NTFSSecurity.format.ps1xml`), and `NTFSSecurity.dll`.
- Documentation: MkDocs (`mkdocs.yml`, theme `readthedocs`, `docs_dir: ./Docs`)
  built by Read the Docs (`.readthedocs.yml` v2); cmdlet pages are platyPS
  0.14 markdown (schema 2.0.0) in `Docs/Cmdlets`.
- Help: `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml`, generated from
  `Docs/Cmdlets` and committed (Decision 8).
- Tests: Pester 5 tests in `Tests` (`Help.Tests.ps1`) against the Release
  build.

## Environment

- Windows only (NTFS, Win32 security APIs).
- The Debug build writes straight into
  `C:\Program Files\WindowsPowerShell\Modules\NTFSSecurity\`.
- No Visual Studio MSBuild or .NET Framework targeting pack on the
  workstation. A local build works with the .NET Framework MSBuild
  (`%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\MSBuild.exe`) plus
  `/p:CscToolPath` to the Roslyn `csc.exe` of the `Microsoft.Net.Compilers`
  package; the legacy C# 5 compiler fails with CS0136. `dotnet msbuild`
  fails on the binary resources in `Resources.resx` (MSB3822, MSB3823).
- platyPS 0.14.2, Pester 5.7.1, PSScriptAnalyzer, and powershell-yaml are
  installed only for PowerShell 7. Windows PowerShell 5.1 imports platyPS
  and Pester by full path
  (`~\OneDrive\Documents\PowerShell\Modules\platyPS\0.14.2`,
  `C:\Program Files\PowerShell\Modules\Pester\5.7.1`) with
  `$env:PSModulePath` cleared. MarkdownLinkCheck is not installed.

## Constraints

- `ModuleVersion` in the source manifest is `4.2.5`; the latest tag and
  Gallery release is `4.2.6`.
- HEAD differs from tag `4.2.6` only by the `Remove-Item2 -PassThur` to
  `-PassThru` rename and `CompatiblePSEditions` in the manifest.
- `CmdletsToExport` lists `Show-NTFSSimpleAccess`, which no longer exists
  (WinForms code removed in `d3063de`), and repeats the inheritance cmdlets.
- `Test-ModuleManifest` fails in Windows PowerShell 5.1:
  `CompatiblePSEditions` requires `PowerShellVersion` 5.1 or higher, and the
  manifest says `2.0` (work package 4).
- Releases have no script and no CI deployment. Evidence from 4.2.6: the
  Gallery DLLs are Debug builds (`DebuggableAttribute` 263), the nuspec
  comes from `Publish-Module`, the package holds the whole output folder
  (`.pdb`, `AlphaFS.xml`, 7 MB `System.Management.Automation.dll`), and the
  published manifest differs from the tag only by `ModuleVersion` (tags
  carry the previous version). GitHub releases attach `NTFSSecurity.zip`.
- CI: AppVeyor project `raandree/ntfssecurity` builds branches and pull
  requests. Read the Docs (`ntfssecurity`) and a second AppVeyor project are
  attached to the fork `Sup3rlativ3/NTFSSecurity`.
- `Get-FileHash2` fails in PowerShell 7; all other cmdlets passed a smoke
  test in PowerShell 7.6.
- `CHANGELOG.md` lists user-visible changes only; CI and build-only changes
  get no entry
  ([Decision 7](decisions/0007-changelog-user-visible-only.md)).
- Remote mutations are the maintainer's: the user-level preToolUse hook
  `Block-RemoteMutation.ps1` denies `git push` and mutating `gh` commands
  (`pr create`, `pr close`, and others) from the agent session, even after
  an explicit request. Its override, `COPILOT_ATELIER_ALLOW_REMOTE=1`, is
  read from the environment that VS Code starts the hook with; setting it
  inside an agent command has no effect (verified 2026-10-04). The hook
  matches the whole command text, so a commit message that quotes such a
  command is blocked too. Prepare the commands and descriptions; the
  maintainer runs them.

## Validation

- CI (`appveyor.yml`, image Visual Studio 2022): restore `packages.config`
  per project plus `Microsoft.NETFramework.ReferenceAssemblies.net452`
  1.0.3, build `NTFSSecurity.csproj` in Release with
  `TargetFrameworkRootPath`/`FrameworkPathOverride`, import
  `NTFSSecurity\bin\Release\NTFSSecurity.psd1`, then: 01 run
  `Update-MarkdownHelp` and fail on `git diff -- Docs/Cmdlets`; 02
  `Get-MarkdownLink -BrokenOnly`; 03 regenerate the help file and fail on
  `git status --porcelain -- NTFSSecurity/en-US`; 04 Pester 5.7.1 on
  `Tests`, each result reported once through the build worker API
  (`POST $env:APPVEYOR_API_URL/api/tests/batch`).
- AppVeyor REST API (public, no token): build
  `api/projects/raandree/ntfssecurity/builds/<buildId>`, job log
  `api/buildjobs/<jobId>/log` (bytes; decode as UTF-8), and test list
  `api/buildjobs/<jobId>/tests`.
- Run platyPS in Windows PowerShell 5.1 to avoid PowerShell 7.4+
  `-ProgressAction` noise.
- Placeholder check: no `{{` left in `Docs/Cmdlets/*.md`.
- Help file: `New-ExternalHelp -Path .\Docs\Cmdlets -OutputPath
  .\NTFSSecurity\en-US -Force` must leave `git status` unchanged.
- Pester: run detached (`Start-DetachedPowerShell.ps1`) in Windows
  PowerShell 5.1; a run without `bin\Release\en-US` must fail.
- Markdown lint: `npx markdownlint-cli2` with `MD013` limited to prose
  (tables, code, and headings excluded) on the conceptual pages.
- YAML: `ConvertFrom-Yaml` (powershell-yaml) on `mkdocs.yml`,
  `.readthedocs.yml`, and `appveyor.yml`; every `nav` target must exist.
- MkDocs needs Python, which this workstation does not have; `mkdocs build
  --strict` was not run.
