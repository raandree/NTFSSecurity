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
- No MSBuild or .NET Framework targeting pack on the 2026-10-02 workstation;
  the released module 4.2.6 and platyPS 0.14.2 were installed.

## Constraints

- `ModuleVersion` in the source manifest is `4.2.5`; the latest tag and
  Gallery release is `4.2.6`.
- HEAD differs from tag `4.2.6` only by the `Remove-Item2 -PassThur` to
  `-PassThru` rename and `CompatiblePSEditions` in the manifest.
- `CmdletsToExport` lists `Show-NTFSSimpleAccess`, which no longer exists
  (WinForms code removed in `d3063de`), and repeats the inheritance cmdlets.
- `NTFSSecurity/NTFSSecurity-Help.xml` is a stale pre-4.x MAML file for old
  command names; binary-module help must be named `NTFSSecurity.dll-Help.xml`.
- Read the Docs (`ntfssecurity`) and AppVeyor are attached to the fork
  `Sup3rlativ3/NTFSSecurity`, not to this repository.
- `Get-FileHash2` fails in PowerShell 7; all other cmdlets passed a smoke
  test in PowerShell 7.6.

## Validation

- Docs drift check (mirrors `appveyor.yml`), run in Windows PowerShell 5.1
  to avoid PowerShell 7.4+ `-ProgressAction` noise: copy `Docs/Cmdlets`, run
  `Update-MarkdownHelp` on the copy against the module, and diff.
- Placeholder check: no `{{` left in `Docs/Cmdlets/*.md`.
- Help build check: `New-ExternalHelp -Path ./Docs/Cmdlets` to a temp folder.
- Markdown lint: `npx markdownlint-cli2` with `MD013` limited to prose
  (tables, code, and headings excluded) on the conceptual pages.
- YAML: `ConvertFrom-Yaml` (powershell-yaml) on `mkdocs.yml` and
  `.readthedocs.yml`; every `nav` target must exist.
- Link check in CI: `Get-MarkdownLink -Path .\Docs\ -BrokenOnly`.
- MkDocs needs Python, which this workstation does not have; `mkdocs build
  --strict` was not run.
