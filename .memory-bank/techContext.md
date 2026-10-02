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

## Constraints

- `ModuleVersion` in the source manifest is `4.2.5`; the latest tag and
  Gallery release is `4.2.6`.
- HEAD differs from tag `4.2.6` only by the `Remove-Item2 -PassThur` to
  `-PassThru` rename and `CompatiblePSEditions` in the manifest.
- `CmdletsToExport` lists `Show-NTFSSimpleAccess`, which no longer exists
  (WinForms code removed in `d3063de`), and repeats the inheritance cmdlets.
- `NTFSSecurity/NTFSSecurity-Help.xml` is a stale pre-4.x MAML file for old
  command names; binary-module help must be named `NTFSSecurity.dll-Help.xml`.
- CI: AppVeyor project `raandree/ntfssecurity` builds branches and pull
  requests. Read the Docs (`ntfssecurity`) and a second AppVeyor project are
  attached to the fork `Sup3rlativ3/NTFSSecurity`.
- `Get-FileHash2` fails in PowerShell 7; all other cmdlets passed a smoke
  test in PowerShell 7.6.
- `CHANGELOG.md` lists user-visible changes only; CI and build-only changes
  get no entry
  ([Decision 7](decisions/0007-changelog-user-visible-only.md)).

## Validation

- CI (`appveyor.yml`, image Visual Studio 2022): restore `packages.config`
  per project plus `Microsoft.NETFramework.ReferenceAssemblies.net452`
  1.0.3, build `NTFSSecurity.csproj` in Release with
  `TargetFrameworkRootPath`/`FrameworkPathOverride`, import
  `NTFSSecurity\bin\Release\NTFSSecurity.psd1`, run `Update-MarkdownHelp`,
  and fail on `git diff -- Docs/Cmdlets`; then `Get-MarkdownLink -BrokenOnly`.
- Run platyPS in Windows PowerShell 5.1 to avoid PowerShell 7.4+
  `-ProgressAction` noise.
- Placeholder check: no `{{` left in `Docs/Cmdlets/*.md`.
- Help build check: `New-ExternalHelp -Path ./Docs/Cmdlets` to a temp folder.
- Markdown lint: `npx markdownlint-cli2` with `MD013` limited to prose
  (tables, code, and headings excluded) on the conceptual pages.
- YAML: `ConvertFrom-Yaml` (powershell-yaml) on `mkdocs.yml`,
  `.readthedocs.yml`, and `appveyor.yml`; every `nav` target must exist.
- MkDocs needs Python, which this workstation does not have; `mkdocs build
  --strict` was not run.
