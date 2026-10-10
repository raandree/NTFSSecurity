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
  follow-up `3442194` 2,641/3,559 (74.21%), 974/1,933 (50.39%);
  Handoff 1 `5a5d58b` 3,192/3,634 (87.84%), 1,273/1,978 (64.36%). Different
  code changes denominators; never present these as same-source incremental
  percentages. The branch summary counts 820 compiler-generated points (185
  visited); report the explicit branch points as well (1,088/1,158, 93.96%).
- Suite at `5a5d58b`: 1,310 per configuration, zero failures. Passed/skipped:
  elevated Desktop 1,286/24, Core 1,255/55; basic Desktop 1,076/234,
  Core 1,045/265.
- NUnit skipped ForEach names retain placeholders and parameter tuples,
  executed names expand them; raw-name intersection and positional alignment
  are invalid. Skip eligibility is checked by row: run the suite once per
  configuration with Pester PassThru (`Get-DiscoveryRows2.ps1 -Run` in the
  session evidence) and match skipped with executed rows by file, line,
  path, name, and data. Discovery alone misses tests that skip themselves
  while they run, and `ConvertTo-Json` of rich data rows never finishes:
  write primitives and type names.
- Remaining inventory: 442 points in 231 methods, classified by rule with
  evidence (probe, IL scan, source reading); see `Tests/Coverage`. Preserve
  raw XML, row CSVs, logs, commit identity, and build hashes. The frozen
  Build rewrites the hash file each time: save the hashes of the measured
  assemblies (AltCover `__Saved` copies) before any mutation build.
- Bounded mutations: one script per round on the frozen worktree, with
  guards that no other mutation of the round can trip (an escape can be an
  overlap or an equivalent mutant: check before changing a test). Restore
  the source exactly and rebuild.
- Red/green matrix, to show afterwards that a guard fails without its fix:
  build each state of the branch (base, then each fix commit) in its own
  Release worktree, lay the final `Tests` over it (`git checkout <final> --
  Tests`), run the guarding files with the focused runner (it sets
  `$ErrorActionPreference` to `Stop` like the CI wrappers) in all four
  configurations, and count failed rows per name with their multiplicity (a
  block whose `BeforeAll` fails lists its data rows under one unexpanded
  template name). The last state is the control and must have no failure.
  Keep the logs and a manifest with their hashes, and hash each build: the
  first red runs of Handoff 1 were deleted and could not be reproduced, and
  the frozen runner rewrites its hash file at each build.

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
  A computer in a domain offers the remote interface to every caller, so the
  denial also hit the default `-ServerName localhost` for a user who isn't an
  administrator; a computer outside a domain doesn't offer it, which is why the
  tests passed on the development host and on CI. Since `fdd7a8b`, the local
  manager answers for a name of this computer when the remote one refuses; the
  denial stays for another computer (live test of the Delegate role).
- A live test is evidence of a fix only when it fails on the build without
  the fix: run the same tests, controller, and lab against the candidate and
  the base of the branch, a new process per edition, and join both result
  sets by edition, role, and full test name; the tests that pass on both are
  controls (`Tests\Lab\Acceptance-2026-10-09-quality-gate-paths.md`). A
  validator must not name a loop variable like a typed parameter: PowerShell
  variables ignore case, so `$edition` overwrote `$Edition` and every edition
  in the CSV became `System.String[]`.
- RemoveFixture after the run; verify OUs/accounts, share, folders, local
  memberships, and test profiles removed. Credentials must never be printed.

### Operating-system matrix (Decision 24)

- Lab `NtfsSecurityOsMatrixLab`: OSDC1 (Server 2025), OSFile19/22/25 (Server
  2019/2022/2025), OSWin11E (Windows 11 Enterprise Evaluation 22H2, the domain
  client), OSWin11 (Windows 11 Pro 26H1, suite only). Kit: `Tests\Lab\Acceptance`;
  record: `Tests\Lab\Acceptance-2026-10-10-os-matrix.md`.
- Run the module's own suite on every machine class before the controller
  (`Run-MatrixLocalSuite.ps1`, elevated and basic, both editions, as scheduled
  tasks with a batch logon at the highest run level): a child of a remoting
  session has every privilege enabled and fails eight tests that expect them
  disabled. Skipped lists are compared as multisets against the host.
- AutomatedLab: one `Import-Lab` at a time, and none while a controller
  sequence runs (it re-imports the lab); `Wait-LabVM` waits for a heartbeat that
  a client may not report, so retry `New-LabPSSession`. The host's `bcdboot`
  leaves the ESP of a Server 2019 or Windows 11 22H2 base image empty.
- Windows PowerShell 5.1: `$PSScriptRoot` is empty in a parameter default under
  `-File`; `2>&1` on a native command under `Stop` makes its stderr line
  terminating; `Get-LocalGroupMember` fails on an orphaned SID; `net localgroup
  <name> <SID> /delete` refuses the SID of a name that its cache still
  resolves (use `Remove-LocalGroupMember -SID`).
- Windows 11 26H1 (28000.1836) loses the secure channel to a Server 2025 domain
  controller (`NetrLogonGetCapabilities` level 2, 0xC0000022): suite only.
  The 22H2 evaluation client shuts down every hour (license grace expired) and
  can lose its machine password after an unplanned shutdown: keep a run under
  an hour from its start, test a domain session (not `nltest /sc_verify`, which
  stays stale), repair with `Test-ComputerSecureChannel -Repair`.
- Builds are not byte-reproducible (two unchanged assemblies differ per build):
  hash each candidate and its package separately.
- The fixture's account for case 3 gets a new name for each new fixture
  (`NtfsLiveSubject` and four digits). In the matrix lab, after an account was
  deleted and created again with the same name, the remote authorization
  managers (the client's for the default `-ServerName`, the file server's for its
  name) answered for about ten minutes as if it had no groups (`0x100000`),
  whichever module version asked, while the Kerberos S4U logon of the oracle, the
  name resolution, and the local manager were right in the same second. A replay
  with the baseline and the final candidate alternating failed the baseline in two
  of three cells and the final candidate in one of three (not counting the warm-up
  cell). The mechanism in Windows is unknown; a model with one lifetime (9.35 to
  10.20 minutes) fits all 43 Admin-role runs of 27 cells. When the accounts are
  created again within seconds, the S4U
  logon itself returns the old account for 7 to 15 minutes. A `klist purge`,
  `nltest /sc_reset`, a DNS flush, and a restart of the Kerberos service didn't
  help. `Probe-AccountRecreation.ps1`, `Export-CellTimeline.ps1`, and
  `Test-StaleAuthzModel.ps1` show it.
