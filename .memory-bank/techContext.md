---
status: current
last-verified: 2026-10-09
owner: active-agent
source: repository and executable evidence
---

# Tech context

## Stack

- Legacy C# projects, .NET Framework 4.5.2, `NTFSSecurity.sln`.
  Cmdlets depend on Security2, PrivilegeControl/ProcessPrivileges, and
  AlphaFS 2.2.x. System.Management.Automation reference: 10.0.10586.0.
- Module supports Windows PowerShell 5.1 and PowerShell 7; 36 cmdlets.
  Manifest initializes helper assemblies, aliases, type data, formatting,
  and committed help generated from `Docs/Cmdlets` (platyPS 0.14/schema 2).
- CI: `.github/workflows/ci.yml`, scripts in `.github/scripts`; GitHub
  renders Docs and publishes a generated wiki. No separate docs site.

## Current environment

- Host `ExHost`: Windows Server 2025 VM, native x64, elevated agent;
  repository `V:\Git\NTFSSecurity`. AutomatedLab 5.61.704, Hyper-V,
  approved lab `WindowsAccessControlLab` (Decision 20).
- Build Release only: Debug writes to Program Files. Native .NET Framework
  MSBuild plus Roslyn `Microsoft.Net.Compilers` 4.2.0 and .NET 4.5.2
  reference assemblies work; legacy compiler fails CS0136, dotnet MSBuild
  fails binary resources MSB3822/MSB3823. Build packages are already cached
  in `packages`; compiler/tools are under TEMP `ntfs-build`.
- Pester 5.7.1 is in
  `V:\Git\WindowsAccessControl\output\RequiredModules\Pester\5.7.1`.
  platyPS 0.14.2 and MarkdownLinkCheck 0.2.0 are under TEMP `ntfs-docs-tools`.
  PSScriptAnalyzer and PSResourceGet are available in PowerShell 7.
- Use Desktop's module paths in Desktop children, not inherited Core-only
  paths. Never import NTFSSecurity in the agent shell; every package/build
  runs in a new process. Current prereleases share assembly version 5.0.0.0.
- GitHub CLI: `C:\Program Files\GitHub CLI\gh.exe`, signed in as raandree.
  Read-only queries work; remote mutations belong to the maintainer.
- LabSources: `V:\LabSources`. All 13 deployed machines are Server 2025.
  Windows 11 consumer/enterprise-evaluation media and Server 2019/2022
  ISO files exist. OS cache is empty; exact detected editions are not yet
  verified. Do not equate present media with a deployed/tested OS matrix.

## Constraints

- Source manifest: ModuleVersion 5.0.0, prerelease rc7 on #116/follow-up.
  Latest stable: 4.2.6; latest published prerelease: rc6 (2026-10-08).
  GitHub rc6 release recovered 2026-10-09. rc7 publication is pending.
- Changed-section writes preserve unchanged owner/group/DACL/SACL (19).
  Roots use root-folder APIs, not AlphaFS device security (#41).
- CHANGELOG contains user-visible changes only (7); tests and CI-only fixes
  get no entry. No stable release until Decision 21 gates close.
- Honor separate topic branches, no amendment, two AI co-author trailers.
  Never work around remote-mutation blocking. Provide each maintainer
  command separately at reply end, no question dialog after commands.
  Issue references use no closing keyword unless closure is intended.
- Lab passwords stay in memory and are lab-only; no secret in repository,
  logs, or process arguments. Live ACL mutations occur only in the lab.
- Existing expired installation passwords of a.forest1/b.forest1 were
  configured not to expire on 2026-10-07, matching the root domain.

## Build and focused checks

- Build `NTFSSecurity\NTFSSecurity.csproj` with Configuration=Release,
  Framework MSBuild, TargetFrameworkRootPath/FrameworkPathOverride to
  `packages\Microsoft.NETFramework.ReferenceAssemblies.net452.1.0.3\build`,
  CscToolPath to the cached compiler. Expected legacy CS1591/CS0618 warnings
  are not new failures. Never copy a mutated DLL into acceptance artifacts.
- Pester/builds run in detached monitored child processes through
  `Start-DetachedPowerShell.ps1`; use unique TEMP logs/result paths and an
  explicit-PID watcher. No foreground sleep/poll loop. Long payloads use
  a script file: nested Base64 encoding can exceed Windows command limits.
- Focused helper: TEMP `ntfs-focused\Start-FocusedRuns.ps1`; detach that
  driver too because its internal wait loop must not block the agent shell.
- TEMP `ntfs-docs-tools\Invoke-ChangeChecks.ps1 -File <relative paths>`
  performs AST/analyzer/lint/help checks. Absolute input paths misroute
  cmdlet pages. Check actual analyzer/lint output, not just helper exit.
- actionlint 1.7.12 checks the workflow. Script changes use AST parse and
  PSScriptAnalyzer; prose Markdown uses MD013 and changelog siblings-only
  repeated-heading allowance. Native error codes must be checked explicitly.
- Documentation: run platyPS in Desktop, generate external help, rebuild,
  require an unchanged Markdown round trip. Links in Docs are checked
  relatively; Wiki tests cover generated anchors, not arbitrary web URLs.

## CI and packaging

- CI `build` on windows-2025 installs tools, restores dependencies, builds
  Release, round-trips pages/help, checks links, and runs the suite in
  Desktop/Core, elevated/basic user. Lab tests are explicitly excluded.
- `.github/scripts/Invoke-TestsAsBasicUser.ps1` launches a SAFER Normal User
  token. Result paths may be absolute or repository-relative: Path.Combine
  then GetFullPath, not Join-Path with a rooted child.
- Packaging needs Compress-PSResource (Core 7.4+). New-ModulePackage copies
  only FileList, validates the manifest, creates nupkg plus NTFSSecurity.zip.
  Check package/file hashes and test the extracted artifact, not build extras.
- Release runs only for validated version tags in powershell-gallery.
  API key stays as PSGALLERY_API_KEY environment reference. Helper
  Publish-ModulePackage treats only PackageNotFound as expected absence;
  existing-version skip and uncertain-upload recovery require exact Gallery
  SHA-512 equality. Base64 comparison is case-sensitive. Unverifiable,
  missing, and different outcomes preserve errors. No test uploads.
- Read status through gh pr checks / gh run view --log-failed. A successful
  Gallery upload followed by HTTP 409 does not prove its retry chronology.

## Coverage and test eligibility

- AltCover 9.0.145 net472 instruments a copied Release build with PDBs,
  OpenCover format, localSource, excluding AlphaFS/System.Management.Automation.
  Do not use --save: collection previously retained only one process's hits.
- Freeze a git worktree, instrument its NTFSSecurity\bin\Release, run all
  four configurations sequentially with the real CI wrappers, then
  AltCover runner --collect recalculates the report. Compute option paths
  before passing native arguments, not inline Join-Path expressions.
- Report sequence points, not unique source lines. Four-run baselines:
  rc5 2,020/3,476 (58.1%), branches 711/1,873 (38.0%);
  rc6 2,412/3,540 (68.14%), branches 850/1,918 (44.32%);
  follow-up `3442194` 2,641/3,559 (74.21%), 974/1,933 (50.39%).
  NTFSSecurity assembly: 1,769/2,099 (84.28%). Different code changes
  denominators; never present these as same-source incremental percentages.
- Final suite: 914 per configuration, zero failures. Passed/skipped:
  elevated Desktop 890/24, Core 860/54; basic Desktop 749/165, Core 719/195.
- NUnit skipped ForEach names retain placeholders and parameter tuples,
  executed names expand them. Strip trailing data tuples and match templates;
  raw-name intersection or positional alignment is invalid across editions.
  139 skipped templates have eligible executed counterparts. Inspect input
  eligibility when an individual data row has a condition of its own.
- Remaining inventory: 918 points, including 244 in cmdlet-unused classes,
  112 parameter-getter points, and 562 awaiting finer classification/testing.
  Preserve raw XML, eligibility CSV, logs, commit identity, and build hashes.

## Lab acceptance

- Defaults: F1ADC1 (domain), F1AFile2 (server), F1AFile1 (client), all in
  a.forest1.net. Foreign accounts use F1BDC1, F2DC1, F3DC1 and existing trusts.
  Controller accepts alternate machines; changing topology/OS scope waits
  for a maintainer decision. Do not repurpose another project's shared VMs.
- Before a run: authenticated WinRM, LDAP RootDSE, Kerberos tickets, member
  secure channels, clocks; checkpoint only approved targets. Inspect actual
  checkpoint kind: new checkpoints reported Standard even after a successful
  temporary ProductionOnly request. Policy restored; no rollback performed;
  Production classification remains unverified, not a passed safety check.
- Run Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 in elevated Desktop with
  -Version for hash-checked Gallery packages or -ModulePath for the extracted
  build artifact, both editions. Per version/edition: Delegate, ServerAdmin,
  Admin on client, then Server independently checks persisted state.
- Controller writes Summary.json even when tests fail: validate every role,
  exit code, failure name, and total; DONE alone is not acceptance evidence.
  Desktop ConvertFrom-Json can wrap arrays; explicitly enumerate the result
  and compare full Describe-prefixed names. Never gate cleanup on the global
  Error.Count, which includes handled errors; independently verify footprint.
- Remote Authz answers administrators and Access Control Assistance
  Operators (S-1-5-32-579); other accounts get access denied. Check firewall
  when remote resource-manager RPC fails. Expected rights use S4U tokens.
- RemoveFixture after the run; verify OUs/accounts, share, folders, local
  memberships, and test profiles removed. Credentials must never be printed.
