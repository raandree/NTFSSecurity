---
status: current
last-verified: 2026-10-20
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
- LabSources: `V:\LabSources`. The first lab's machines are Server 2025; the
  matrix lab `NtfsSecurityOsMatrixLab` adds Server 2019/2022 and Windows 11.

## Constraints

- Manifest: ModuleVersion 5.0.0, prerelease rc8 (tag at `c719197`; `ai/rc9`
  sets rc9). Latest stable 4.2.6. `$publishedVersions` ends at rc7; the reuse
  test fails if it holds the manifest's version, so rc9 adds rc8, stable rc9.
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
- Helpers live in the session folder `qg-unknowns\scripts`, not in TEMP (TEMP was
  cleaned once): `Invoke-Build.ps1`, `Start-FocusedRuns.ps1` (four
  configurations), `Run-FullSuite.ps1` (the CI test steps), `Check-Docs.ps1`.
  Restore the pinned compiler (Microsoft.Net.Compilers 4.2.0 from NuGet) into
  TEMP `ntfs-build` and platyPS 0.14.2 and MarkdownLinkCheck 0.2.0 (`Save-Module`
  in Windows PowerShell) into TEMP `ntfs-docs-tools\modules`.
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
- Release runs only for validated version tags in powershell-gallery; the API
  key is the environment secret PSGALLERY_API_KEY. The rules of
  `Publish-ModulePackage` are in `systemPatterns.md`. Read status through
  `gh pr checks` and `gh run view --log-failed`. A successful Gallery upload
  followed by HTTP 409 does not prove its retry chronology.

## Coverage and test eligibility

- AltCover 9.0.145 net472 instruments a copied Release build with PDBs,
  OpenCover format, localSource, excluding AlphaFS/System.Management.Automation.
  Do not use --save: collection previously retained only one process's hits.
- Freeze a git worktree, instrument its NTFSSecurity\bin\Release, run all
  four configurations sequentially with the real CI wrappers, then
  AltCover runner --collect recalculates the report. Compute option paths
  before passing native arguments, not inline Join-Path expressions.
- Report sequence points, not unique source lines. Four-run baselines:
  `3442194` 2,641/3,559 (74.21%); `5a5d58b` 3,192/3,634 (87.84%); `fa0701b`
  (rc7) 3,198/3,649 (87.64%); `61e936e` 3,258/3,664 (88.92%). The code
  changes the denominators: never present these as same-source increments.
  The branch summary of the tool adds a point to most methods (never visited
  for the 626 without a branch): report the explicit branch points
  (1,090/1,168, 93.32%), not the summary percentage. Suite at `61e936e`: 1,459
  per configuration, zero failures (skipped: 26 and 57 elevated, 276 and 307
  basic, Desktop and Core).
- NUnit skipped ForEach names retain placeholders and parameter tuples,
  executed names expand them: raw-name intersection and positional alignment
  are invalid. Check skip eligibility by row: run the suite once per
  configuration with Pester PassThru and match skipped with executed rows by
  file, line, path, name, and data (discovery alone misses tests that skip
  while running; write primitives, as `ConvertTo-Json` of rich rows hangs).
- Live and domain-member coverage: instrument a copy of the package without
  `--portable`, with an absolute report path outside the payload
  (`C:\NtfsMatrixProbe\Coverage`, `icacls` Authenticated Users modify) and a
  SYSTEM task that snapshots the report after each process (a role that is not
  an administrator of the client can't write next to the module). It counts
  only when its counts equal the uninstrumented acceptance and every role
  logged a flush. Merge by position, never by `uspid`. PowerShell reads the
  getter of a parameter that it binds from a piped object: unvisited getters
  point at missing pipeline tests.
- Remaining inventory at `61e936e`: 406 points in 187 methods, classified by
  rule (`Tests/Coverage`). Preserve raw XML, row CSVs, logs, commit identity,
  and build hashes: the frozen Build rewrites its hash file, so save the
  hashes of the measured assemblies (AltCover `__Saved` copies) first.
- Mutation proofs: bounded one-statement changes on a second frozen worktree,
  source restored exactly and rebuilt (an escape can be an overlap, an
  equivalent mutant, or a masked case: check before changing a test). Red/green
  matrix for a fix: build each state in its own Release worktree, lay the
  final `Tests` over it, count failed rows per name in all four
  configurations, and keep logs and hashes (Handoff 1's first red runs were
  deleted and could not be reproduced).

## Lab acceptance

- Defaults: F1ADC1 (domain), F1AFile2 (server), F1AFile1 (client), all in
  a.forest1.net. Foreign accounts use F1BDC1, F2DC1, F3DC1 and existing trusts.
  Controller accepts alternate machines; changing topology/OS scope waits
  for a maintainer decision. Do not repurpose another project's shared VMs.
- Before a run: authenticated WinRM, LDAP RootDSE, Kerberos tickets, member
  secure channels, clocks; checkpoint only approved targets. New checkpoints
  report Standard even after a successful ProductionOnly request (policy
  restored, no rollback): Production is unverified, not a passed safety check.
- Run Tests\Lab\Invoke-NTFSSecurityLabTest.ps1 in elevated Desktop with
  -Version for hash-checked Gallery packages or -ModulePath for the extracted
  build artifact, both editions. Per version/edition: Delegate, ServerAdmin,
  Admin on client, then Server independently checks persisted state.
- Controller writes Summary.json even when tests fail: validate every role,
  exit code, failure name, and total; DONE alone is not acceptance evidence.
  Desktop ConvertFrom-Json can wrap arrays: enumerate the result and compare
  full Describe-prefixed names. Never gate cleanup on the global Error.Count
  (it includes handled errors); verify the footprint independently.
- Remote Authz answers administrators and Access Control Assistance
  Operators (S-1-5-32-579); other accounts get access denied (check the
  firewall when its RPC fails). Expected rights use S4U tokens. A domain
  member offers the remote interface to every caller, so the default
  `-ServerName localhost` was denied for a non-administrator; hosts outside a
  domain don't, so the host and CI missed it. Since `fdd7a8b` the local
  manager answers for a name of this computer; another computer stays denied.
- A live test is evidence of a fix only when it fails on the build without
  the fix: run the same tests, controller, and lab against the candidate and
  the base, a new process per edition, and join the results by edition, role,
  and full test name; tests that pass on both are controls (record of
  2026-10-09). PowerShell variables ignore case: `$edition` overwrote
  `$Edition`.
- RemoveFixture after the run; verify OUs/accounts, share, folders, local
  memberships, and test profiles removed. Credentials must never be printed.

### Operating-system matrix (Decision 24)

- Lab `NtfsSecurityOsMatrixLab`: OSDC1 (Server 2025), OSFile19/22/25 (Server
  2019/2022/2025), OSWin11E (Windows 11 Enterprise Evaluation 22H2, the domain
  client), OSWin11 (Windows 11 Pro 26H1, suite only). Kit
  `Tests\Lab\Acceptance`; record
  `Tests\Lab\Acceptance-2026-10-10-os-matrix.md` (procedure, limits);
  the lessons of building it are in `deployment-notes.md`.
- Run the module's own suite on every machine first (`Run-MatrixLocalSuite.ps1`
  as scheduled tasks with a batch logon at the highest run level; a remoting
  child has every privilege enabled). One `Import-Lab` at a time. Compare skips
  as multisets against the host. Hash each candidate and its package: builds
  aren't byte-reproducible.
- The 26H1 client can't keep its secure channel to a Server 2025 DC (suite
  only); the 22H2 evaluation client shuts down every hour: keep a run under an
  hour and test a domain session, not `nltest /sc_verify`.
- A fixture that re-creates an account name gets stale answers for about ten
  minutes, for the baseline and the candidate alike (mechanism unknown; no
  remedy but waiting). The controller names the case-3 account anew for each
  fixture; the replay and the model are in the record. `Test-MatrixCleanup.ps1`
  verifies and repairs the probe's profiles and group entries.
