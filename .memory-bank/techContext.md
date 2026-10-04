---
status: current
last-verified: 2026-10-04
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
- Documentation: Markdown in `Docs` and `README.md`, rendered by GitHub and
  published to the wiki by CI; no documentation site (Decisions 9 and 11).
  Cmdlet pages are platyPS 0.14 markdown (schema 2.0.0) in `Docs/Cmdlets`.
- Help: `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml`, generated from
  `Docs/Cmdlets` and committed (Decision 8).
- Tests: Pester 5 tests in `Tests`: `Help.Tests.ps1` (help of every
  cmdlet), `Manifest.Tests.ps1` (manifest and versions, Decision 10), and
  `Remove-Item2.Tests.ps1` (`-PassThur` alias) against the Release build;
  `Wiki.Tests.ps1` (wiki conversion) without a build.
- CI: GitHub Actions, `.github/workflows/ci.yml` with the scripts in
  `.github/scripts` (Decision 11).

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
  installed only for PowerShell 7. Windows PowerShell 5.1, started from
  PowerShell 7, imports platyPS and Pester by full path
  (`~\OneDrive\Documents\PowerShell\Modules\platyPS\0.14.2`,
  `C:\Program Files\PowerShell\Modules\Pester\5.7.1`). Leave
  `$env:PSModulePath` alone: PowerShell 7 hands the child the Windows
  PowerShell default path, and clearing it leaves Windows PowerShell without
  its core modules (Pester fails: `Add-Member` not found).
- MarkdownLinkCheck is not installed, and `Save-Module` crashed (FailFast)
  in PowerShell 7.6 on 2026-10-04. Download the 0.2.0 package from
  `https://www.powershellgallery.com/api/v2/package/MarkdownLinkCheck/0.2.0`
  into `$env:TEMP`, extract it, and import it by path.
- The workstation is ARM64; PowerShell 7 runs as x64 under emulation.
  Python 3.12.10 (ARM64) is installed per user with winget, the
  maintainer's choice for an MkDocs check that Decision 9 made unnecessary.
- The NuGet cache (`~\.nuget\packages`) holds every build dependency: copy
  `alphafs\2.2.1`, `system.management.automation.dll\10.0.10586`, and
  `microsoft.netframework.referenceassemblies.net452\1.0.3` into
  `packages\<Id>.<Version>`, and point `CscToolPath` at
  `microsoft.net.compilers\4.2.0\tools`.

## Constraints

- `ModuleVersion` is `5.0.0` on `ai/manifest-version` (work package 4,
  unreleased; `master` still says `4.2.5`); the latest tag and Gallery
  release is `4.2.6`. The manifest requires PowerShell 5.1 and .NET
  Framework 4.5.2, uses `RootModule`, and lists exactly 36 cmdlets;
  `Test-ModuleManifest` passes in Windows PowerShell 5.1 and PowerShell 7.6.
- Besides the shipped help file and its tests (#93), the module source at
  `master` differs from tag `4.2.6` only by the `Remove-Item2 -PassThur`
  to `-PassThru` rename and `CompatiblePSEditions` in the manifest; work
  package 4 adds the manifest and version changes and the `-PassThur`
  alias.
- Releases have no script and no CI deployment. Evidence from 4.2.6: the
  Gallery DLLs are Debug builds (`DebuggableAttribute` 263), the nuspec
  comes from `Publish-Module`, the package holds the whole output folder
  (`.pdb`, `AlphaFS.xml`, 7 MB `System.Management.Automation.dll`), and the
  published manifest differs from the tag only by `ModuleVersion` (tags
  carry the previous version). GitHub releases attach `NTFSSecurity.zip`.
- CI: GitHub Actions on pull requests and pushes to `master` (Decision 11).
  The AppVeyor project `raandree/ntfssecurity` builds until the maintainer
  deletes it after the GitHub Actions PR is merged. The Read the Docs
  project `ntfssecurity` (maintainer `Sup3rlativ3`) and a second AppVeyor
  project are attached to the fork `Sup3rlativ3/NTFSSecurity`, which no
  longer exists (GitHub 404, 2026-10-04). That site still serves pages from
  2020 and isn't used (Decision 9).
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

- CI (`.github/workflows/ci.yml`): job `build` on `windows-2025` installs
  platyPS 0.14.2, MarkdownLinkCheck 0.2.0, and Pester 5.7.1 for all users,
  restores `packages.config` per project plus
  `Microsoft.NETFramework.ReferenceAssemblies.net452` 1.0.3, builds
  `NTFSSecurity.csproj` in Release with the MSBuild that `vswhere` finds,
  then: 01 `Update-MarkdownHelp` and fail on `git diff -- Docs/Cmdlets`; 02
  `Get-MarkdownLink -BrokenOnly`; 03 regenerate the help file and fail on
  `git status --porcelain -- NTFSSecurity/en-US`; 04 `Invoke-Tests.ps1` in
  Windows PowerShell 5.1 and in PowerShell 7. Job `wiki` on `ubuntu-latest`
  clones the wiki (`gh auth setup-git` with the built-in token), runs
  `Export-WikiContent.ps1`, lists the changed pages in the job summary, and
  publishes from `master` only. Actions are pinned by commit SHA:
  `actions/checkout` v7.0.1, `actions/upload-artifact` v7.0.1.
- Read CI runs with `gh run list --repo raandree/NTFSSecurity --workflow
  ci.yml` and `gh run view <id> --log-failed` (read-only). While AppVeyor
  still builds: `api/projects/raandree/ntfssecurity/history`, build
  `api/projects/raandree/ntfssecurity/builds/<buildId>`, job log
  `api/buildjobs/<jobId>/log` (public, no token).
- Workflow lint: actionlint (download the release zip into `$env:TEMP` and
  check its SHA-256 against the checksum file); PowerShell steps check
  `$LASTEXITCODE` after every native command, because GitHub checks only
  the last one.
- Run platyPS in Windows PowerShell 5.1 to avoid PowerShell 7.4+
  `-ProgressAction` noise.
- Placeholder check: no `{{` left in `Docs/Cmdlets/*.md`.
- Help file: `New-ExternalHelp -Path .\Docs\Cmdlets -OutputPath
  .\NTFSSecurity\en-US -Force` must leave `git status` unchanged.
- Pester: run detached (`Start-DetachedPowerShell.ps1`) in Windows
  PowerShell 5.1: the launcher starts `pwsh`, and its payload runs
  `powershell.exe -NoProfile -EncodedCommand` with Pester imported by full
  path. A run without `bin\Release\en-US` must fail.
- Markdown lint: `npx markdownlint-cli2` with `MD013` limited to prose
  (tables, code, and headings excluded) on the conceptual pages.
- YAML: `ConvertFrom-Yaml` (powershell-yaml) on `.github/workflows/ci.yml`.
- Links: the CI step 02 (MarkdownLinkCheck 0.2.0) checks only relative
  links in `Docs`; it strips anchors and skips absolute URLs.
  `Wiki.Tests.ps1` checks the wiki links with their anchors; check the
  links in `README.md` and `CHANGELOG.md` with a script.
