---
status: current
last-verified: 2026-11-11
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

- Manifest: ModuleVersion 5.0.0, prerelease rc9 (tag at `823c814`, published
  2026-10-22). Latest stable 4.2.6. `$publishedVersions` ends at rc8; the reuse
  test fails if it holds the manifest's version, so stable adds rc9.
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
  cleaned twice): `Invoke-Build.ps1`, `Start-FocusedRuns.ps1`,
  `Run-FullSuite.ps1` (the CI test steps), `Check-Docs.ps1`, and
  `Restore-BuildTools.ps1` (compiler 4.2.0 into TEMP `ntfs-build`, AltCover into
  `ntfs-coverage-tools`: run it before the first build). platyPS 0.14.2 and
  MarkdownLinkCheck 0.2.0 (`Save-Module`, Windows PowerShell) go into TEMP
  `ntfs-docs-tools\modules`.
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
- Packaging needs Compress-PSResource (Core 7.4+); New-ModulePackage copies
  only FileList, validates the manifest, creates nupkg plus NTFSSecurity.zip:
  check the hashes and test the extracted artifact (Decision 12). Release runs
  only for validated version tags (`PSGALLERY_API_KEY`; the rules of
  `Publish-ModulePackage` are in `systemPatterns.md`). Read status through
  `gh pr checks` and `gh run view --log-failed`.

## Coverage and test eligibility

- AltCover 9.0.145 net472 instruments a copied Release build with PDBs
  (OpenCover, localSource, excluding AlphaFS/System.Management.Automation;
  never --save: collection kept one process's hits). Freeze a worktree,
  instrument its Release output, run the four configurations sequentially with
  the CI wrappers, then `runner --collect`. Compute option paths first.
- Report sequence points, not unique source lines. Four-run baselines:
  `3442194` 2,641/3,559 (74.21%); `fa0701b` (rc7) 3,198/3,649; `2112ee3`
  3,266/3,668; `823c814` (rc9) 3,666/4,074 with the tests of the tag and
  3,672/4,074 (90.13%) with 52 new cases. The code changes the denominators:
  never present these as same-source increments. The branch summary of the
  tool adds a point to most methods: report the explicit branch points
  (1,322/1,410, 93.76% at rc9). Suite at rc9: 2,214 cases per configuration
  (skipped: 27 and 58 elevated, 359 and 390 basic, Desktop and Core).
- NUnit skipped ForEach names keep placeholders and executed names expand
  them: raw-name intersection and positional alignment are invalid. Check skip
  eligibility by row: run the suite once per configuration with Pester PassThru
  and match skipped with executed rows by file, line, path, name, and data
  (discovery misses tests that skip while running; write primitives only).
- Live and domain-member coverage: instrument a copy of the package without
  `--portable`, with an absolute report path outside the payload and a SYSTEM
  task that snapshots the report after each process (a non-administrator can't
  write next to the module). It counts only when its counts equal the
  uninstrumented acceptance and every role logged a flush; merge by position,
  never by `uspid`. PowerShell reads the getter of a piped parameter: unvisited
  getters point at missing pipeline tests.
- Remaining inventory at rc9: 402 points in 169 methods, classified by 35 rules
  (`Tests/Coverage`; the first matching rule wins, so check the rows of a rule
  you edit). Keep raw XML, row CSVs, logs, and build hashes. To add tests to a
  measured tag, lay them over the same pristine bytes (check the hashes) and
  analyze with `-SourceRoot` of the first tree (the PDBs hold its paths). The
  package has no PDBs: compare the IL of the build with it (Mono.Cecil; ten
  benign differences at rc9).
- Mutation proofs: bounded one-statement changes on a second frozen worktree,
  rebuilt and restored exactly (an escape can be an overlap, an equivalent
  mutant, or a masked case: check before changing a test). A mutation run is a
  sample: keep the full list of failed tests, not the first two names. Red/green
  matrix for a fix: build each state in its own Release worktree, lay the
  final `Tests` over it, count failed rows per name in all four
  configurations, and keep logs and hashes.

## Lab acceptance

- Defaults: F1ADC1 (domain), F1AFile2 (server), F1AFile1 (client), all in
  a.forest1.net; foreign accounts use F1BDC1, F2DC1, F3DC1. The controller
  accepts alternate machines; a change of topology or OS scope waits for a
  maintainer decision. Do not repurpose another project's shared VMs.
- Before a run: authenticated WinRM, LDAP RootDSE, Kerberos tickets, member
  secure channels, clocks; checkpoint only approved targets (a new checkpoint
  reports Standard even after a successful ProductionOnly request: Production
  is unverified, not a passed safety check).
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
  Operators (S-1-5-32-579); other accounts get access denied. Expected rights
  use S4U tokens. A domain member offers the remote interface to every caller,
  so the default `-ServerName localhost` was denied for a non-administrator;
  hosts outside a domain don't, so the host and CI missed it. Since `fdd7a8b`
  the local manager answers for a name of this computer.
- A live test is evidence of a fix only when it fails on the build without
  the fix: run the same kit against the published base and the candidate
  (`-Version`, a new process per edition) and join by edition, role, and full
  test name (`Compare-Detect.ps1`). At rc9, 79 of the 191 tests of case 11 per
  edition fail on rc8 and pass on rc9, each for the documented reason; 112
  pass on both. Variable names ignore case: `$detectVersions` overwrote the
  `[string] $DetectVersions` parameter, so `[0]` was a character, not a version.
- The delegated account has no Restore privilege on the file server: it can
  take an owner and can't give Administrators back (error 1307), the lab's one
  way to a `RestoreOwnerError` (7 of the 17 handlers; the rest can't be driven).
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
  only). The 22H2 evaluation client shuts down an hour after each start: test a
  domain session, not `nltest /sc_verify`. With case 11 the three cells take
  about 25 minutes and a suite 11 to 33, so run the suites in a second window
  (stop and start the client, gate on a lab-account session; no repair needed).
- A fixture that re-creates an account name gets stale answers for about ten
  minutes (mechanism unknown; no remedy but waiting). The controller names the
  case-3 account anew for each fixture. `Test-MatrixCleanup.ps1` verifies and
  repairs the probe's profiles and group entries.
