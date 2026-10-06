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
  `System.Management.Automation.dll` 10.0.10586.0. For a drive or volume
  root, AlphaFS `DirectoryInfo` reaches the device object, while
  `Directory.Get/SetAccessControl('C:\')` reaches the root folder (#41).
- Module: `NTFSSecurity.psd1` loads `NTFSSecurity.psm1` (aliases `dir2`,
  `gi2`, `rm2`, `del2`), `NTFSSecurity.Init.ps1` (Add-Type of the helper
  assemblies, prepends `NTFSSecurity.format.ps1xml`), and `NTFSSecurity.dll`.
- Documentation: Markdown in `Docs` and `README.md`, rendered by GitHub and
  published to the wiki by CI; no documentation site (Decisions 9 and 11).
  Cmdlet pages are platyPS 0.14 markdown (schema 2.0.0) in `Docs/Cmdlets`.
- Help: `NTFSSecurity\en-US\NTFSSecurity.dll-Help.xml`, generated from
  `Docs/Cmdlets` and committed (Decision 8).
- Tests: Pester 5 in `Tests`, one file per area, against the Release
  build; `Wiki.Tests.ps1` (wiki conversion) runs without a build.
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
- The first workstation is ARM64; PowerShell 7 runs as x64 under emulation.
- The NuGet cache (`~\.nuget\packages`) holds every build dependency: copy
  `alphafs\2.2.1`, `system.management.automation.dll\10.0.10586`, and
  `microsoft.netframework.referenceassemblies.net452\1.0.3` into
  `packages\<Id>.<Version>`, and point `CscToolPath` at
  `microsoft.net.compilers\4.2.0\tools`.
- The second workstation (x64, used since 2026-10-05) runs the agent
  session elevated, so the tests that need privileges run there as in CI.
  It has no NuGet cache with these packages: download each from
  `https://api.nuget.org/v3-flatcontainer/<id>/<version>/<id>.<version>.nupkg`,
  extract the first three into `packages\<Id>.<Version>` and the compilers
  into `$env:TEMP`; Pester 5.7.1 comes from the Gallery package API the
  same way, its folder first on `$env:PSModulePath` of the test process.
  The GitHub CLI is in `C:\Program Files\GitHub CLI`, outside the PATH of
  sessions started before its installation.

## Constraints

- `ModuleVersion` on `master` is `5.0.0` with the prerelease label `rc4`.
  The latest stable tag and Gallery release is `4.2.6`. The manifest
  requires PowerShell 5.1 and .NET Framework 4.5.2, uses `RootModule`, and
  lists exactly 36 cmdlets; `Test-ModuleManifest` passes in Windows
  PowerShell 5.1 and PowerShell 7.6.
- The module source at `master` differs from tag `4.2.6` by the changes
  that `CHANGELOG.md` lists under `[Unreleased]`, the release notes of each
  5.0.0 prerelease.
- PowerShell Gallery versions (publish dates): 4.0.0 (2015-08-19), 4.2.2
  (2016-05-18), 4.2.3 (2016-05-19), 4.2.4 (2018-08-13), 4.2.5 (2019-07-11),
  4.2.6 (2019-07-12), none with release notes; 5.0.0-rc1 (2026-10-04),
  5.0.0-rc2 (2026-10-05), 5.0.0-rc3 and 5.0.0-rc4 (2026-10-06), published
  by CI. Older versions were released on CodePlex only, and their dates are
  lost. The git history starts on 2016-10-10, when the project moved from
  CodePlex.
- Releases up to 4.2.6 were Debug builds published by hand, with the whole
  output folder; their tags carry the previous version. From 5.0.0 on, CI
  publishes on a version tag (Decision 12). GitHub releases attach
  `NTFSSecurity.zip`.
- CI: GitHub Actions on pull requests, pushes to `master`, and version tags
  (Decision 11); AppVeyor and Read the Docs aren't used (Decision 9).
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
  maintainer runs them. Hand over each command as its own fenced code block
  at the end of the reply, which the chat shows with a copy button, and end
  the turn there; the maintainer reports back in the chat. The question
  dialog joins the lines of its text, has no copy button, and covers the
  reply before it (maintainer, 2026-10-06). A pull request description
  names an issue without a closing keyword (fixes, closes, resolves) unless
  the merge should close it: "fixes #34" in #112 closed #34. Simulated `gh`
  commands in offline tests must print what the real ones print, such as
  the URL of a new comment.

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
  (read-only) clones the wiki (`gh auth setup-git` with the built-in token),
  runs `Export-WikiContent.ps1`, and lists the changed pages in the job
  summary; job `publish-wiki` (`contents: write`) repeats that and publishes,
  for `master` only. After the tests, `build` runs
  `New-ModulePackage.ps1` and uploads the artifact `packages` (nupkg and
  `NTFSSecurity.zip`). Job `release` runs only for tags matching
  `[0-9]+.[0-9]+.[0-9]+` or `[0-9]+.[0-9]+.[0-9]+-*`, in the environment
  `powershell-gallery` (secret `PSGALLERY_API_KEY`); see Decision 12.
  Actions are pinned by commit SHA: `actions/checkout` v7.0.1,
  `actions/upload-artifact` v7.0.1, `actions/download-artifact` v8.0.1;
  Dependabot proposes updates weekly, one week after a release.
- Packaging needs PSResourceGet (`Compress-PSResource`, PowerShell 7.4 or
  later); its tests skip in Windows PowerShell. Dry run locally: run
  `New-ModulePackage.ps1` against `NTFSSecurity\bin\Release` into
  `$env:TEMP`, then extract the nupkg into a folder and import it there.
- Read CI runs with `gh run list --repo raandree/NTFSSecurity --workflow
  ci.yml`, `gh pr checks <number>`, and `gh run view <id> --log-failed`
  (read-only).
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
- Tests that run only without a privilege skip in CI and in an elevated
  session. Run them as a basic user with `runas /trustlevel:0x20000`, and
  give Windows PowerShell its own `PSModulePath`; that token holds one
  privilege, so the `Enable-Privileges -PassThru` count test fails there.
- Markdown lint: `npx markdownlint-cli2` with `MD013` limited to prose
  (tables, code, and headings excluded) on the conceptual pages; for
  `CHANGELOG.md` also `MD024` with `siblings_only: true`, because every
  version repeats the category headings.
- Gallery packages: download
  `https://www.powershellgallery.com/api/v2/package/NTFSSecurity/<version>`
  into `$env:TEMP` and extract it; dates come from the OData endpoint
  `api/v2/FindPackagesById()?id='NTFSSecurity'`. Import each version in its
  own process: every version's `NTFSSecurity.dll` has assembly version
  4.2.1.0, so a second version in the same process reuses the first DLL.
- YAML: `ConvertFrom-Yaml` (powershell-yaml) on `.github/workflows/ci.yml`.
- Links: the CI step 02 (MarkdownLinkCheck 0.2.0) checks only relative
  links in `Docs`; it strips anchors and skips absolute URLs.
  `Wiki.Tests.ps1` checks the wiki links with their anchors; check the
  links in `README.md` and `CHANGELOG.md` with a script.
