# Quality gate, the coverage unknowns, 2026-10-10

Handoff 5 of the quality gate before 5.0.0 (Decision 21). Handoff 1 measured
the C# coverage of the unit suite at `5a5d58b` and explained the unvisited
paths from source; an explanation is not a test. This report measures what
was still unmeasured and tests what the new numbers show. It does not close
the gate: the stable 5.0.0 stays blocked, the open items of the
[paths report](Quality-Gate-Paths-2026-10-09.md) stay with the maintainer, and
a coverage percentage never closes a gate. Nothing was pushed, merged, tagged,
or published.

The work is on `ai/coverage-unknowns`, from `origin/master` at `6696f68`
(PR #123). Every stage is described below; the
[completion matrix](#completion-matrix) says which unknown is closed and which
is open.

## Result in short

- **The shipped code.** The unit suite of the host visits 3,198 of 3,649
  sequence points (87.64%) of rc7 (`fa0701b`) and 1,090 of 1,168 explicit
  branch points (93.32%). All 232 unvisited methods are classified.
- **The live tests and the domain member.** The live suite (the first lab and
  three cells of the matrix lab) and the unit suite on a domain member give
  the counts of the uninstrumented acceptance, and together they add 9
  sequence points and 4 explicit branch points, all of the effective-access
  code of `fdd7a8b`. The matrix adds nothing to the first lab. No test and no
  probe visits `AUDIT-OWNER-RETRY` or `AUDIT-READ-DENIED`; they stay open.
- **The tests.** 79 new `It` blocks (140 rows) in four files close or narrow
  the gaps of the judged matrix of the 64 parameter sets: 7 sets closed, 51
  partly, 1 open, 4 left to the maintainer. The unit suite then visits 45
  more sequence points, all getters of parameters with pipeline input, which
  corrects an explanation of the paths report. At the final commit `b2cb47b`
  the suite has 1,455 cases per configuration without a failure and covers
  3,243 sequence points (88.87%).
- **A defect fixed, a defect open.** The comparison of an identity with a name
  was wrong in `tr-TR`; it is fixed test-first (`419cfb3`). The hard-link
  cmdlets (`New-NTFSHardLink -PassThru`, `Get-NTFSHardLink`) fail for a path
  whose root is not the volume root; the defect is reproduced and left to the
  maintainer.
- **Environments.** `de-DE` and `tr-TR` are tested; Server Core has a plan;
  ARM64, a localized system, and non-Windows servers stay open.

## Tables

| File | Content |
| --- | --- |
| [Methods](Quality-Gate-Unknowns-2026-10-10-Methods.csv) | the 232 unvisited methods of `fa0701b` with the rule, the category, the disposition, and what the other sources and the final build visit |
| [Cmdlets](Quality-Gate-Unknowns-2026-10-10-Cmdlets.csv) | per cmdlet, the visited sequence and explicit branch points of each source |
| [Reconciliation](Quality-Gate-Unknowns-2026-10-10-Reconciliation.csv) | the 232 methods against the 231 of `5a5d58b` |
| [ParameterSets](Quality-Gate-Unknowns-2026-10-10-ParameterSets.csv) | the judged matrix of the 64 sets and its status after the new tests |
| [Mutations](Quality-Gate-Unknowns-2026-10-10-Mutations.csv) | the 35 mutations of the new tests |
| [LiveRoles](Quality-Gate-Unknowns-2026-10-10-LiveRoles.csv) | the points that each role of the live suite visits |
| [Cultures](Quality-Gate-Unknowns-2026-10-10-Cultures.csv) | the unit suite in `de-DE` and `tr-TR` |
| [Runs](Quality-Gate-Unknowns-2026-10-10-Runs.csv) | the counts of every run of the report |
| [Evidence](Quality-Gate-Unknowns-2026-10-10-Evidence.csv) | the files outside git, with size and SHA-256 |

## Candidate and source identity (Stage A)

- Measured source: the tag `5.0.0-rc7`, commit
  `fa0701b591098ec6a6fab2ef12fe2c31d7fc7e88`, the code of the published rc7.
  `origin/master` holds the same code: since the tag, 13 files changed, all in
  the Memory Bank, the lab acceptance record, and the lab README.
- Against `5a5d58b` (the measurement of the paths report), the production C#
  changed in three files by 70 insertions and 27 deletions: `fdd7a8b`
  (effective access for a user who is not an administrator,
  `Security2\Win32\Lib.cs`), `962887a` (audit inheritance by path and by
  descriptor, `Security2\FileSystem\FileSystemSecurity2.cs`), and `9205f40` (a
  comment in `NTFSSecurity\BaseCmdlets.cs`). The unit tests grew by 31 lines
  in `Tests\Inheritance.Tests.ps1`, the live tests by 623 lines.
- Build: Release, .NET Framework 4.5.2, 0 errors and 317 warnings (296 of
  CS1591, 19 of CS1574, one of CS0169, one of CS0618), the same as at
  `5a5d58b`. None was suppressed.
- Tools: Windows PowerShell 5.1.26100, PowerShell 7.6.6, Pester 5.7.1,
  AltCover 9.0.145 (net472), on one Windows Server 2025 host.
- The measured assemblies are the Release files that the Validate run used;
  AltCover saved them unchanged (`__Saved`) before it instrumented them. The
  Release build is not byte-reproducible, so the hashes identify the measured
  files, not the source.

| Assembly | SHA-256 |
| --- | --- |
| `NTFSSecurity.dll` | `6749E31430320EA92698F3475A33433A965BE9558C0C7B34797CDAAAF88700DB` |
| `Security2.dll` | `BE8A186D4D542009B95792A8FC5EFC3F21EEC11DC1694BAFB7F4F7D616B066E0` |
| `ProcessPrivileges.dll` | `BAD3C7AFAF328AE6002AC2F6E81F9F79236CA5B2F9A281BBAA9A7153D49E54B5` |
| `PrivilegeControl.dll` | `81F15234907EBD4678E174DD6E4EC637B859C54FC54E00DAA1A68BC0C20B9F0B` |

## Method of Stage A

The method of the paths report, in one frozen worktree outside the
repository (`git worktree add --detach`, the junction `packages`). Three
modes of `Run-Frozen.ps1`, in this order, because Coverage instruments
`bin\Release` in place:

- Build: native .NET Framework MSBuild with
  `/p:Configuration=Release /t:Rebuild`, the cached Roslyn 4.2.0 compiler
  (`CscToolPath`), and the .NET 4.5.2 reference assemblies
  (`TargetFrameworkRootPath`, `FrameworkPathOverride`).
- Validate: the four configurations without instrumentation, with the CI
  wrappers `.github\scripts\Invoke-Tests.ps1` (elevated) and
  `Invoke-TestsAsBasicUser.ps1` (a restricted token), in Windows PowerShell
  5.1 and PowerShell 7. The run fails when a configuration has a failure or
  another case count than the first.
- Coverage: `AltCover.exe --inputDirectory=<bin\Release> --report=<xml>
  --reportFormat=OpenCover --localSource
  --assemblyFilter=AlphaFS|System.Management.Automation --inplace`, the four
  configurations one after the other, then `AltCover.exe runner --collect
  --recorderDirectory=<bin\Release>`. Never `--save`: that kept the hits of one
  process only.

Skip eligibility is checked by row, on a second, uninstrumented copy of the
same build (the same bytes, hash-checked): one Pester process per
configuration records every row with its file, line, path, name, data, and
result, and a skipped row needs the same row executed in another
configuration. Raw names are not used: NUnit keeps the placeholders of a
skipped data row.

## Local validation

Each configuration discovered 1,314 test cases (1,310 at `5a5d58b`); no test
failed. The four new cases are two `It` blocks of `Tests\Inheritance.Tests.ps1`
with two data rows each (the audit state of an item by path and by
descriptor, `962887a`); the second block skips in the basic-user
configurations, because it changes audit entries.

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,290 | 0 | 24 | 1,314 |
| Windows PowerShell 5.1, basic user | 1,078 | 0 | 236 | 1,314 |
| PowerShell 7, elevated | 1,259 | 0 | 55 | 1,314 |
| PowerShell 7, basic user | 1,047 | 0 | 267 | 1,314 |

The instrumented runs gave the same counts. The skipped rows are 582 rows of
138 distinct tests (354 rows with data), against 578 and 137 at `5a5d58b`.
Every skipped row has the same test, with the same data, executed in two other
configurations; no skipped row lacks an executed counterpart.

## Coverage of the shipped code

| Assembly | Sequence points | Sequence coverage | Branch points | Branch coverage |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 1,912/2,168 | 88.19% | 683/1,094 | 62.43% |
| Security2 | 1,061/1,240 | 85.56% | 509/753 | 67.59% |
| ProcessPrivileges | 205/219 | 93.61% | 72/125 | 57.60% |
| PrivilegeControl | 20/22 | 90.91% | 12/17 | 70.59% |
| Aggregate | 3,198/3,649 | 87.64% | 1,276/1,989 | 64.15% |

The ratios are visited sequence or branch points divided by their totals, not
unique source lines. The branch summary counts 821 compiler-generated points
(patterns such as `foreach` and `using`), of which 186 are visited; the
explicit branch points that a person wrote are 1,090/1,168 (93.32%).

### Against `5a5d58b`

| | `5a5d58b` | `fa0701b` | Difference |
| --- | ---: | ---: | --- |
| Sequence points | 3,192/3,634 (87.84%) | 3,198/3,649 (87.64%) | +6 visited, +15 points |
| Branch points | 1,273/1,978 (64.36%) | 1,276/1,989 (64.15%) | +3 visited, +11 points |
| Explicit branch points | 1,088/1,158 (93.96%) | 1,090/1,168 (93.32%) | +2 visited, +10 points |
| Unvisited methods | 231 | 232 | one new method |
| Unvisited sequence points | 442 | 451 | +9 |
| Unvisited explicit branch points | 70 | 78 | +8 |

Only `Security2` changed (1,055/1,225 to 1,061/1,240 sequence points, 506/742
to 509/753 branch points); the other three assemblies have the same counts.
The code is different, so the two measurements are not increments of one
source. The ratios fell by 0.2 points because the new code is mostly paths
that the host cannot run: `Security2` gained 15 sequence points and 6 of them
are visited (`FileSystemSecurity2` +2 of 2, from `962887a`; `Win32` +4 of 13,
from `fdd7a8b`).

### Reconciliation of the 231 methods

By assembly, class, and method, against the inventory of `5a5d58b`: 220
methods are unchanged (the same points and the same lines); 8 only moved
(`TryGetDriveRoot`, the two conversions of `FileSystemSecurity2`,
`GetHashCode`, `GetByteSecurityDescriptor`, `GetRawSecurityDescriptor`,
`GetEffectiveAccess`, and `GetEffectivePermissions_AuthzAccessCheck` changed
lines, not points, because code was inserted above them); 3 are changed by the
code of the commits; none is now fully visited and none is gone; one method is
new (232 in all).

| Method (`Security2.Win32`) | Unvisited at `5a5d58b` | Unvisited at `fa0701b` | What changed |
| --- | --- | --- | --- |
| `GetEffectivePermissions_AuthzInitializeResourceManager` | 3 sequence, 3 branch | 4 sequence, 6 branch | the remote interface is asked only for a name; the success path, and a refusal of this computer, are new branches |
| `GetEffectivePermissions_AuthzInitializeContextFromSid` | 0 sequence, 1 branch | 6 sequence, 4 branch | the fallback to the local manager for a refusal of this computer |
| `GetEffectivePermissions_AuthzInitializeLocalResourceManager` | (part of the method above) | 1 sequence, 1 branch | new method, split out by `fdd7a8b` |
| `IsLocalComputer` | 2 sequence, 0 branch | 3 sequence, 1 branch | its guard for an empty name is no longer reachable: the only caller checks the name first |

The net change is +9 sequence points and +8 explicit branch points, which is
the whole difference of the table above. The audit read of `962887a` in
`FileSystemSecurity2` adds no unvisited point: the unit suite runs it.

### Classification

The rule of a method stays where the method and its code are unchanged. The
old rule `WIN32-AUTHZ-FAILURE` matched by class and method name, so it had
absorbed the four changed methods with an explanation that does not describe
their new code. Its scope is narrowed to the two methods whose code did not
change (`GetEffectiveAccess`, `GetEffectivePermissions_AuthzAccessCheck`), and
the new code has rules of its own: `AUTHZ-INIT-ERROR`, `AUTHZ-LOCAL-FALLBACK`,
`AUTHZ-LOCAL-RM-FAILURE`, and the extended `WIN32-LOCAL-NAME-LOOKUP`. Every
one of the 232 methods has a rule; none is unclassified.

One explanation of the paths report is corrected, and the new tests of Stage C
showed it (the section on the result of those tests has the evidence). The rule
`CMDLET-GETTER` said of all 103 getters of cmdlet parameters that PowerShell
binds a parameter through its setter, so that no caller invokes the getter.
That holds for a parameter without pipeline input (46 getters). PowerShell
reads the getter of a parameter that it binds from a piped object, by value or
by property name, so the 57 getters of parameters with pipeline input were
reachable and untested, not explained. They have the new rule
`CMDLET-GETTER-PIPELINE`, with the disposition Open.

| Category | Disposition | Methods | Unvisited sequence points | Unvisited explicit branch points |
| --- | --- | ---: | ---: | ---: |
| unused by cmdlets | Explained | 60 | 173 | 34 |
| parameter/API surface | Explained | 46 | 46 | 0 |
| defensive | Explained | 34 | 79 | 18 |
| environment-specific | Explained | 27 | 88 | 24 |
| unused by cmdlets | Open | 8 | 8 | 2 |
| parameter/API surface | Open | 57 | 57 | 0 |
| **Total** | | **232** | **451** | **78** |

"Explained" means a source-backed explanation exists, not that a test runs the
path; the 8 open methods of the category "unused by cmdlets" are those of the
paths report (`FileSecurity` conversions, `RemoveAll` account filters).

## Stage B: the live tests and the domain member

The host that measured Stage A is in a workgroup and runs one user at a time,
without a file server. Code stays out of its reach when it needs a computer in
a domain (which offers the remote interface of its authorization manager to
every caller), an account that is not an administrator of that computer, or
SMB. This stage measures that code with the assemblies of Stage A.

### Design

The module under test runs as three domain accounts (the roles Delegate,
ServerAdmin, and Admin of `Tests\Lab\Invoke-NTFSSecurityLabTest.ps1`) on a
client that receives a copy of the module folder, in both editions. AltCover
fixes the path of its report when it instruments, and its recorder adds the
visits of a process to that report when the process ends. So the design has to
answer where the report lives, who may write it, and how the visits come back.

The instrumented module is built on the host from the extracted package of the
Stage A build, with the PDBs of the same build next to the assemblies. The
four input assemblies are byte-identical to the measured files of Stage A (the
hashes above), and the zero-hit report holds the same 3,649 sequence points and
1,989 branch points. The command:

```powershell
AltCover.exe --inputDirectory=<in> --outputDirectory=<out>\NTFSSecurity `
    --report=C:\NtfsMatrixProbe\Coverage\coverage.xml --reportFormat=OpenCover `
    --localSource '--assemblyFilter=AlphaFS|System.Management.Automation'
```

Repeating this command on the same input gave the same four instrumented
assemblies and the same report, byte for byte; only the generated recorder
differs.

| Instrumented file | SHA-256 |
| --- | --- |
| `NTFSSecurity.dll` | `64AC86D13CFB35650CE1386CD8E769569889FB54C9828DF27D5CC6AAF49E67B3` |
| `Security2.dll` | `A415FC0D32E81A7D88E01B684939889F9604AF4602AA931ED3B61CDD5F14D280` |
| `ProcessPrivileges.dll` | `2EDD77650122A12E27093943882DE872D52E06F63AB78C44378C27BFDE815B34` |
| `PrivilegeControl.dll` | `3B025E3C3B64DBB99473F4D3416EED76E01D06C2AF26ACF48545AC12EFF7883F` |
| `AltCover.Recorder.g.dll` | `A521BDBF19D711FF75D44B094CC808401251912DF08D3D158DF7C9A0F5F2F160` |
| zero-hit report | `B29CAD26164A2667DCBE631DD74565638E192540CB48A45A1E4290CA8904BC06` |

The measurement counts only if the instrumented run gives the counts of the
uninstrumented acceptance: 245 passed and 1 skipped per edition in the first
lab (roles 69, 36, 64, and 76), exit code 0 for every role, and one flush line
of the recorder in the log of every role that runs the module.

**First design, rejected: the report next to the module.** `--portable` makes
the recorder write `coverage.xml` next to its own assembly, which is the
folder that the controller copied to the client. It worked on the host in both
editions. In the first lab (`fl1b`) the role ServerAdmin is not an
administrator of the client, and the folder of the copied module
(`C:\NTFSSecurityLab`) inherits its permissions from `C:\`, where Windows
Server 2025 gives Authenticated Users no right to write (Windows 11 does). The
report has no visit of that role (its log has no flush line), and in PowerShell
7 its process ended with the exit code `-532462766` (0xE0434352, the code of a
.NET exception) after all 36 tests had passed. The Windows PowerShell run kept
the counts (245, 0, 1) but lost a role, and the PowerShell 7 run was rejected
(`LIVE_RESULT_NOT_ACCEPTED`). Evidence: `E\live-fl1b`.

**Second design, accepted: a report outside the module and a watcher.** The
report path is absolute and outside the payload, `C:\NtfsMatrixProbe\Coverage`.
Per client, before the run, the host creates that folder with
`icacls <folder> /grant *S-1-5-11:(OI)(CI)M` (Authenticated Users, modify),
copies the zero-hit report into it, and starts a task as `SYSTEM`
(`NtfsMatrixCoverageWatch`, `Watch-Coverage.ps1`) that copies the report to
`snapshots\snap-<n>-<time>.xml` whenever its write time changes. After the run
the host copies back `coverage.xml` and the snapshots, removes the folder, the
task, and the script, and verifies that they are gone. A visit count in the
report is the number of processes that flushed a visit of the point, and a
snapshot is cumulative: a role visited a point when the count rose at its
snapshot (the roles run in the order Delegate, ServerAdmin, Admin, one process
each per edition). The controller is called once per edition, so each edition
has its own report. The recorder prints "Coverage statistics flushing took N
seconds"; the driver counts these lines per role log as the proof that the
role flushed.

### The first lab

`WindowsAccessControlLab` (client `F1AFile1`, file server `F1AFile2`, domain
controllers `F1ADC1`, `F1BDC1`, `F2DC1`, `F3DC1`), one run (`fl2`), both
editions: 245 passed, 0 failed, 1 skipped in each, the roles Delegate, 69;
ServerAdmin, 36; Admin, 64; Server, 76; the exit code of every role 0; one
flush line each for the three roles that run the module; three snapshots per
edition; the end state of the lab verified as clean. The two editions wrote
byte-identical reports (SHA-256
`FDAE013DB89EA024BD248FEF54449DF9C6C8C9D4AAF3396F204E15132F849C28`): the
same tests visit the same points.

| Source | Sequence points | Explicit branch points |
| --- | ---: | ---: |
| Unit suite (host, Stage A) | 3,198 | 1,090 |
| Live, role Delegate | 1,548 | 418 |
| Live, role ServerAdmin | 1,117 | 270 |
| Live, role Admin | 1,442 | 359 |
| Live, any role | 1,861 | 509 |
| Union of unit suite and live | 3,207 | 1,094 |
| Live and not unit | 9 | 4 |

The live suite alone visits 1,861 of 3,649 sequence points (51.0%). It adds
9 sequence points and 4 explicit branch points to the unit suite, all in
`Security2.Win32`; no other assembly gains a point:

| Assembly | Sequence points | Unit | Live | Union | Live and not unit |
| --- | ---: | ---: | ---: | ---: | ---: |
| `NTFSSecurity` | 2,168 | 1,912 | 1,145 | 1,912 | 0 |
| `Security2` | 1,240 | 1,061 | 599 | 1,070 | 9 |
| `ProcessPrivileges` | 219 | 205 | 107 | 205 | 0 |
| `PrivilegeControl` | 22 | 20 | 10 | 20 | 0 |

The 9 points are the code that `fdd7a8b` added to the effective-access check:

- the success path of the remote interface of the authorization manager
  (`Security2\Win32\Lib.cs`, lines 200 to 202, branch at 198), which all three
  roles visit, because the client is a computer in a domain;
- the fall back to the local authorization manager for a refusal of this
  computer (lines 272 to 277, branch at 270), which only the role ServerAdmin
  visits: the two tests of `NTFSSecurity.Live.Tests.ps1` at lines 478 and 486
  (`Get-NTFSEffectiveAccess` for a domain account as an account that is not an
  administrator of the client, with and without `-ServerName`).

The fourth explicit branch point is the refusal of another computer, which
stays an error: the role Delegate visits it with the test at line 456
(`Get-NTFSEffectiveAccess` as an account that is not an administrator of the
file server, expecting `GetEffectiveAccessError` and the native error 5).

The visits of the unit suite and the live suite are merged by position
(assembly, class, method, offset, line), never by `uspid`, because the two
runs are different recorders of the same bytes.

### The unit suite on a domain member

The unit suite ran on `OSFile25` of the matrix lab (Windows Server 2025
Datacenter 26100.32690, a member of the domain), with the instrumented module
of the live runs, as the 18 behavior files of `Run-MatrixLocalSuite.ps1`: 1,011
cases of the 1,314 of the full suite (the other seven files check the
manifest, the help, the repository, the wiki, the release scripts, and the
basic-user wrapper). It ran elevated and as a basic user, in both editions
(`E\localsuite-osfile25`). The tests come from the frozen worktree of
`fa0701b`, not from this branch. The counts equal the uninstrumented acceptance
of rc7 on the same machine
([the rc7 suite results](../Lab/Acceptance-2026-10-10-published-rc7-LocalSuite.csv)):

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 994 | 0 | 17 | 1,011 |
| Windows PowerShell 5.1, basic user | 782 | 0 | 229 | 1,011 |
| PowerShell 7, elevated | 992 | 0 | 19 | 1,011 |
| PowerShell 7, basic user | 780 | 0 | 231 | 1,011 |

Against the unit suite of the host, the domain member adds 9 sequence points
and 3 explicit branch points: the same code of `fdd7a8b` that the role
ServerAdmin reaches. The success path of the remote interface is visited in all
four configurations. The fall back to the local authorization manager is
visited only in the two basic-user configurations, which is the case that
`fdd7a8b` fixed: a non-administrator on a domain member gets "Access is
denied" from the remote interface of the computer, and the local authorization
manager answers instead. The unit tests that call `Get-NTFSEffectiveAccess`
are in `Access.Tests.ps1`, `PipelineControl.Tests.ps1`, `PathErrors.Tests.ps1`,
and `Owner.Tests.ps1`; the attribution to one test was not measured. The live
suite adds exactly one explicit branch point beyond that: the refusal of
another computer.

| Union | Sequence points | Explicit branch points |
| --- | ---: | ---: |
| Unit suite of the host | 3,198 | 1,090 |
| plus the unit suite on the domain member | 3,207 | 1,093 |
| plus the first-lab live suite | 3,207 | 1,094 |

The domain member tells which unit tests reach the code of `fdd7a8b`; the live
suite tells that the lab accounts reach it too. Neither run adds a point to
`NTFSSecurity.dll`.

### The cells of the matrix lab

`OSWin11E` (Windows 11 Enterprise Evaluation 22H2, the client of every cell)
with each file server of the matrix lab: `OSFile19`, `OSFile22`, and `OSFile25`
(Windows Server 2019, 2022, and 2025). One controller call per cell, with both
editions in it (`Run-LiveCoverageMatrix2.ps1`, the run `mx1`), the cells one
after the other. `OSWin11E` started at 20:11:47Z and the last cell ended at
20:41:22Z, within the hour that the evaluation image allows.

| Cell | Windows PowerShell 5.1 | PowerShell 7 | Roles that flushed | Snapshots | End state |
| --- | --- | --- | --- | ---: | --- |
| `OSFile19` | 229 passed, 0 failed, 2 skipped | 229 passed, 0 failed, 2 skipped | 3 of 3 in each | 6 | clean |
| `OSFile22` | 229 passed, 0 failed, 2 skipped | 229 passed, 0 failed, 2 skipped | 3 of 3 in each | 6 | clean |
| `OSFile25` | 229 passed, 0 failed, 2 skipped | 229 passed, 0 failed, 2 skipped | 3 of 3 in each | 6 | clean |

The counts are those of the uninstrumented acceptance (Delegate 69,
ServerAdmin 36, Admin 51, Server 73, with 2 skipped), so the measurement
counts. Each cell visits 1,861 sequence points and 509 explicit branch points,
and the points are the same ones as in the first lab: no point is visited by
one cell and not by the first lab, in any of the three cells. The operating
system of the file server and of the client does not change which code the
tests run. In every cell and edition only the role ServerAdmin visits the
fall back of `fdd7a8b` (the line 272 of `Lib.cs`), and all three roles visit
the success of the remote interface (line 200).

| Union | Sequence points | Explicit branch points |
| --- | ---: | ---: |
| Unit suite of the host (Stage A) | 3,198/3,649 (87.64%) | 1,090/1,168 (93.32%) |
| plus the unit suite on `OSFile25` | 3,207 | 1,093 |
| plus the first lab, the three cells, and the probe | 3,207/3,649 (87.89%) | 1,094/1,168 (93.66%) |
| Visited by no source | 442 | 74 |

All sources together add 13 points to the host unit suite, 9 sequence and 4
explicit branch points, in two methods of `Security2.Win32`
(`GetEffectivePermissions_AuthzInitializeResourceManager`, 4 points, and
`...AuthzInitializeContextFromSid`, 9 points). Visited by no source remain 442
sequence points and 74 explicit branch points of the 232 classified methods.

### The questions of the handoff

**Which test visits the code of `fdd7a8b`?** Two groups of tests, in both
editions. The unit suite as a basic user on a domain member (`OSFile25`) visits
the fall back to the local authorization manager; the live tests of the role
ServerAdmin (`NTFSSecurity.Live.Tests.ps1`, lines 478 and 486) visit it in the
first lab and in every cell. The success of the remote interface is visited by
every run on a domain member (all three roles, and the unit suite elevated and
as a basic user). The refusal of another computer, which stays an error, is
visited by the test of the role Delegate at line 456. One branch of the method
is visited by nothing: the answer "RPC server unavailable" of the context
initialization, which does not throw (`Lib.cs`, line 280). It needs a remote
computer that answers the initialization of the resource manager and stops
answering before the context is made.

**Which test visits `AUDIT-OWNER-RETRY` and `AUDIT-READ-DENIED`?** None. No
role, edition, cell, or the unit suite on the domain member visits one point of
these two rules, and neither does the probe below. The live tests run the audit
cmdlets over SMB (`Audit cmdlets on a share folder`, lines 326 to 407, and
`Audit inheritance cmdlets and Clear-NTFSAudit on share folders`, line 621):
the roles that hold the Security privilege on the file server succeed, and the
role Delegate, which does not, gets a `ReadSecurityError`, `AddAceError`, or
`RemoveAceError` whose message names the missing privilege (error 1314, an
`IOException`), not an `UnauthorizedAccessException`.

**Can a test reach them?** What makes a file server answer an audit write with
access denied? The probe (`Probe-AuditDenied.ps1`, the first lab,
`E\probe-auditdenied`) asked this of a Windows file server: as the
installation account (an administrator of the client and of the file server,
who holds the Security privilege there), eight calls of the audit cmdlets
(`Get-NTFSAudit` for a folder and for a file, `Get-NTFSOrphanedAudit`,
`Add-NTFSAudit`, `Remove-NTFSAudit`, `Clear-NTFSAudit`,
`Disable-NTFSAuditInheritance`, and `Enable-NTFSAuditInheritance`) ran against
temporary shares with Full, Change, and Read share permission, in both
editions: 48 calls, and none wrote an error, so the share permission does not
make the file server answer access denied. Together with the earlier probes
(local NTFS as a basic user: error 1314; as an administrator with the
privilege: no exception; a loopback administrative share: no exception) no
trigger was found on a Windows file server, and a test cannot inject the
exception. The two rules stay "Explained" and are listed as open: an answer of
a file server that is not a Windows server (Handoff 4, #34, out of scope) or a
seam for fault injection (a design change) would close them. The probe removed
its shares, folders, and the coverage folder, and the end state was verified.

## Stage C: the reachable gaps

After Stages A and B, no cmdlet reaches an unvisited point that has no
source-backed explanation: the 232 unvisited methods of the host unit suite are
classified (451 sequence points), and 9 of those points are now visited on a
domain member and in the lab. What a point count does not show is whether the
parameter sets are tested as behavior. So this stage tests the matrix, not the
numbers.

### The scan of the parameter sets

`Get-CmdletMetadata.ps1` dumps the 36 cmdlets of the measured module with their
64 parameter sets, parameters, aliases, and flags (a child process; the module
is never imported into the agent shell). `Scan-ParameterSets.ps1` parses the
test files and the live tests (nothing runs) and decides for each of 749
invocations which set it can bind: a call counts for a set when that set is the
only one that its named and positional arguments allow; a splat or a pipe is
judged by what is visible, and an invocation that leaves several sets is
ambiguous and not counted. The scan reproduces the paths report: 57 of the 64
sets have an invocation in the unit tests, and the same 7 have none, and 37
have an invocation in the live tests (`E\paramsets\scan2-ParameterSets.csv`).

The seven sets without a unit invocation are invoked by splat, pipe, or
position, which a parser cannot count. A reader checked each of them (Handoff
5: "check the seven sets first"): every one is bound by at least one test, but
by one or two only, and none is tested for the state on disk, the error, and
the pipeline together:

| Set | Bound by | What binds it |
| --- | ---: | --- |
| `Add-NTFSAudit` SDSimple | 2 | `PermissionScopes.Tests.ps1:146` (a splat), `Audit.Tests.ps1:89` (positions 2 and 3) |
| `Get-NTFSOrphanedAudit` SD | 2 | `Audit.Tests.ps1:243` and `:294` |
| `Get-NTFSOwner` SecurityDescriptor | 1 | `SecurityDescriptorSets.Tests.ps1:146` (a pipe) |
| `Remove-NTFSAccess` PathSimple | 1 | `PermissionScopes.Tests.ps1:99` (a splat) |
| `Remove-NTFSAccess` SDSimple | 1 | `PermissionScopes.Tests.ps1:99` (a splat) |
| `Remove-NTFSAudit` PathSimple | 1 | `PermissionScopes.Tests.ps1:159` (a splat) |
| `Remove-NTFSAudit` SDSimple | 1 | `PermissionScopes.Tests.ps1:159` (a splat) |

### The judged matrix

Four reviewers (one per group of cmdlets: access, audit, inheritance and owner,
items and links), each reading the test files and the live tests, judged every
set: the tests that bind it (file, line, title), what they assert about the
state on disk, the error (ID, category, target), pipeline input, continuation
after a failing item, and the output (`-PassThru`), the live evidence, and the
gap. A gap is `TestNeeded` when a test can close it without a design decision,
`MaintainerDecision` when it would pin behavior that an open item of the paths
report may change, and `None` otherwise. The table is [the ParameterSets
CSV](Quality-Gate-Unknowns-2026-10-10-ParameterSets.csv).

| Group | Sets | `TestNeeded` | `MaintainerDecision` | `None` |
| --- | ---: | ---: | ---: | ---: |
| Access | 18 | 14 | 4 | 0 |
| Audit | 14 | 14 | 0 | 0 |
| Inheritance and owner | 18 | 17 | 0 | 1 |
| Items and links | 14 | 14 | 0 | 0 |
| **Total** | **64** | **59** | **4** | **1** |

| Dimension | Yes | Partly | No | Not applicable |
| --- | ---: | ---: | ---: | ---: |
| State on disk asserted | 15 | 26 | 0 | 23 |
| Error asserted (ID, category, target) | 16 | 22 | 16 | 10 |
| Pipeline input tested | 7 | 8 | 45 | 4 |
| Continuation after a failing item | 17 | 16 | 20 | 11 |
| Output (`-PassThru`) asserted | 31 | 29 | 0 | 4 |

Six sets are bound by one test only, and 30 by ten or more. The weakest
dimension is the pipeline: 45 of 64 sets have no test that pipes into them (a
search for `| <cmdlet>` in the tests finds five pipelines: `Get-NTFSAccess`,
`Get-NTFSOwner`, and `Get-NTFSAudit` after `Get-NTFSSecurityDescriptor`, and
`Get-NTFSOwner` and `Set-NTFSOwner` after `Get-Item` and `Get-Item2`). The four
`MaintainerDecision` rows are the `-SecurityDescriptor` sets of `Add-NTFSAccess`
and `Remove-NTFSAccess`: a failing change ends them with a terminating error,
and no test may pin that before the open item 1 of the paths report is decided.
The one `None` row is `Set-NTFSSecurityDescriptor`, where all five dimensions
are asserted; its remaining untested combinations (positional binding, the
by-property-name pipeline form, and the category and target of one error) are
in the table.

The judged table was checked before use. All 215 citations of a test (file,
line, and title) were compared with the test files of the base commit
`6696f68`: 212 lie inside the `It` that the title names, and the other 3 are
rows of the data table `$stopCases` of `PipelineControl.Tests.ps1` (lines 124,
148, and 164) that feed the data-driven `It` at line 453. Four claims of the
gaps were checked against the source: the five pipelines above (a search), the
single splat that binds the `Remove-NTFSAccess` simple sets
(`PermissionScopes.Tests.ps1:99`), the one read-back of the descriptor of
`Add-NTFSAccess` SDSimple (`Access.Tests.ps1:898`), and the cited tests of the
`None` row.

### The new tests

Four implementers (one agent per group of the judged matrix) each wrote one new
file in a worktree of its own, from `6696f68`, test-first against the built
module, without a production change. Each `It` asserts persisted state, an
error ID with its category and target, continuation, or an output type; none
asserts only an English message. Each file has a bounded mutation proof: a
one-statement change of the C# in a second, discarded worktree, the source
restored exactly and the module rebuilt after every change. The table of the
35 mutations is [the Mutations CSV](Quality-Gate-Unknowns-2026-10-10-Mutations.csv).

| File | `It` blocks | Rows | Passed and skipped in each configuration (5.1 elevated, 7 elevated, 5.1 basic, 7 basic) | Mutations caught |
| --- | ---: | ---: | --- | ---: |
| `ParameterSets.Access.Tests.ps1` | 20 | 26 | 26 and 0 in all four | 8 of 8 |
| `ParameterSets.Audit.Tests.ps1` | 20 | 30 | 29 and 1, 29 and 1, 9 and 21, 9 and 21 | 8 of 9 |
| `ParameterSets.Inheritance.Tests.ps1` | 20 | 48 | 47 and 1, 47 and 1, 31 and 17, 31 and 17 | 9 of 10 |
| `ParameterSets.Items.Tests.ps1` | 19 | 36 | 36 and 0, 36 and 0, 34 and 2, 34 and 2 | 8 of 8 |
| Total | 79 | 140 | | 33 of 35 |

The two mutations that no new test caught are explained in the CSV and do not
point at a hole in the suite as a whole: the `-AppliesTo` conversion for the
Simple audit sets is masked on a file target (the existing
`PermissionScopes.Tests.ps1` catches it on a folder with 24 failures), and
removing `ValueFromPipeline` from `Disable-NTFSAuditInheritance -Path` is
invisible to a test that pipes `Get-ChildItem2` objects, because their
`FullName` property binds it by property name. One mutation of the inheritance
group (the owner of the first descriptor, `Set-NTFSOwner -SecurityDescriptor`)
escaped the first version of the test and was caught after the test got a
direct call with an array: the pipeline hands the cmdlet one descriptor per
call, so an index bug that always acts on the first one cannot show in a test
that only pipes. The tests of three `-SecurityDescriptor` cmdlets
(`Get-NTFSOwner`, `Set-NTFSOwner`, `Set-NTFSInheritance`) now call the
parameter with an array too; the other `-SecurityDescriptor` sets were not
tested that way.

What the controller checked. Every commit changes exactly one new file (the
fix `419cfb3` aside); the four files parse and have no analyzer finding (two
warnings of the algorithm `MD5` in the items file were removed by passing the
algorithm in a variable, `994506d`). The merged branch runs the whole suite in
the four configurations without a failure (the final measurement below), the
skipped rows have an executed counterpart by row, and the audit implementer
re-tested the claim that the owner retry of an audit write cannot be forced on
a local volume: `Block-TestWritePermission` denies only `WRITE_DAC`, and a
SACL write needs only the Security privilege, so with and without the block no
error was written. The independent review of the finished diff is described
below.

### What the new tests add to the coverage

The new tests add 45 sequence points and no explicit branch point. At the final
commit the unit suite of the host visits 3,243 of 3,649 sequence points
(88.87%), against 3,198 (87.64%); every one of the 45 points is a getter of a
cmdlet parameter in `NTFSSecurity.dll` (1,912 to 1,957 of 2,168 points, 88.19%
to 90.27%); the explicit branch points stay at 1,090 of 1,168 (93.32%). The
reconciliation of the unvisited methods of the two builds has 187 methods that
are unchanged and 45 that are visited now; no method is changed or new.

All 45 getters belong to parameters that take pipeline input. This is the
measured proof of the finding of the judged matrix (45 of 64 sets had no test
that pipes into them) and the proof that the explanation of the paths report
for the getters was wrong: PowerShell reads the getter of a parameter when it
binds the parameter from a piped object. Of the 58 getters that stay
unvisited, 46 belong to parameters without pipeline input (nothing reads them,
so they stay explained), and 12 belong to parameters that take pipeline input
by property name, for which no test pipes an object that has that property. The
12 are listed as open, because a test can close them: `Add-NTFSAccess`
(`AccessType`, `AppliesTo`, `InheritanceFlags`, `PropagationFlags`),
`Add-NTFSAudit` and `Remove-NTFSAudit` (`AuditFlags`), `Remove-NTFSAccess`
(`AppliesTo`), `Get-NTFSEffectiveAccess` and `Set-NTFSOwner` (`Account`),
`Copy-Item2` and `Move-Item2` (`Destination`), and `Get-FileHash2`
(`Algorithm`). For `AppliesTo` of the two access cmdlets a test would meet the
finding below.

| | At `fa0701b` | At the final commit |
| --- | ---: | ---: |
| Unvisited methods | 232 | 187 |
| Unvisited sequence points | 451 | 406 |
| Unvisited explicit branch points | 78 | 78 |
| Explained methods | 167 (60, 46, 34, 27) | 167 |
| Open methods | 65 (8 unused, 57 getters) | 20 (8 unused, 12 getters) |

### What the new tests found

- **A defect of the hard-link cmdlets (open item, not fixed).**
  `New-NTFSHardLink -PassThru` and `Get-NTFSHardLink` combine the apparent root
  of the path that the caller gave (`Path.GetPathRoot`) with the names that
  Windows returns for the hard links of the file, and those names are relative
  to the root of the real volume. When the two roots differ, the link is
  created, but `-PassThru` ends in an uncaught, terminating
  `System.IO.FileNotFoundException`, and `Get-NTFSHardLink` writes `FileNotFound`
  for a file that exists. Reproduced with a substituted drive in both editions
  (`E\probes\hardlink-root`, `repro.ps1`, `repro-Desktop.txt`, `repro-Core.txt`).
  A volume that is mounted into a folder, and a junction or a symbolic link to
  another volume, have the same mismatch in the code, and nobody ran them (no
  second volume was mounted); a junction to a folder of the same volume does not
  trigger it, which was run. A UNC path is not affected: the listing of the
  names is not supported there (error 50), and the cmdlets handle that. It is
  not in the open items of the paths report and not a design choice that a test
  can pin, so it is a defect by Decision 16. It is not fixed here: a correct fix
  needs the real volume root of the file, for example from
  `Path.GetFinalPathNameByHandle` of AlphaFS for a handle of the file (the
  internal `CreateFile` of `Security2\Win32` opens one), which is new code in
  the path of two cmdlets that opens the file at every call, and it has to
  decide which names to return when the path crosses a mount point (the names
  under the real volume, or under the root that the caller gave). That is a
  change of the output of two cmdlets for the maintainer. The failing call is
  the regression test for the fix.
- **A piped property does not select the Simple set.** An object with an
  `AppliesTo` property, piped into `Add-NTFSAccess` or `Remove-NTFSAccess`,
  does not bind the Simple set: the mandatory parameters of the default
  Complex set are already satisfiable from the same object, so PowerShell
  resolves the set before it binds the property, and the property is dropped
  without a message; the entry gets the default scope of the Complex set. A
  call that names `-AppliesTo` selects the Simple set. The judged notes had
  assumed the opposite. Not pinned: whether that is intended is the
  maintainer's decision, and it is why the getter of `AppliesTo` stays
  unvisited.
- **The `-SecurityDescriptor` cmdlets and the pipeline.** See the mutation
  `Set-NTFSOwner` above: a test that only pipes descriptors cannot show that a
  cmdlet always acts on the first one.
- **A claim of the judged notes was false.** `Get-NTFSOwner -SecurityDescriptor`
  on a descriptor that was read without its owner section would, by code
  reading, return a null owner and throw. Run (read-only): a security
  descriptor read with only the `Access` section still carries the owner
  (the same effect that Decision 19 records for a write), so there is no
  exception; the gap is a plain test gap, not a risk that a test would pin.
- **A lesson for the tests.** In Pester 5 a variable that `BeforeDiscovery`
  sets is not visible inside the body of an `It` at run time; a test that
  skips from its body has to compute the flag again in `BeforeAll`.

### What stays open in the matrix

After the tests, of the 64 sets: 7 are closed (every gap that the judge named
is asserted), 51 are partly closed, 1 is open, 4 are `MaintainerDecision`, and 1
is `None`. 58 of the 64 sets have at least one new test; the six without one
are the four `MaintainerDecision` sets, `Set-NTFSSecurityDescriptor` (`None`),
and `Test-Path2` (open: its pipeline input was already partly tested, and the
implementer ranked it last). The table with the remaining gap of every set and
its reason is [the ParameterSets CSV](Quality-Gate-Unknowns-2026-10-10-ParameterSets.csv).

| Group | Closed | Partly | Open | `MaintainerDecision` | `None` |
| --- | ---: | ---: | ---: | ---: | ---: |
| Access (18) | 2 | 12 | 0 | 4 | 0 |
| Audit (14) | 3 | 11 | 0 | 0 | 0 |
| Inheritance and owner (18) | 2 | 15 | 0 | 0 | 1 |
| Items and links (14) | 0 | 13 | 1 | 0 | 0 |
| **Total (64)** | **7** | **51** | **1** | **4** | **1** |

The remaining items of the 52 sets that are not closed carry one of four
reasons, counted by mention: 68 `budget` (the implementer stopped at the
target of 15 to 20 blocks per file; plain test work that needs no decision and
no lab), 16 `Limit` (a remote file server or a lab is needed, such as the owner
retry of an audit write or a `PermissionDenied` category), 7
`MaintainerDecision` (open item 1 of the paths report), and 3 `would-pin` (a
test would pin a behavior that a maintainer may change). 32 sets have only
`budget` items left. Such items are the long paths over 260 characters,
bracket paths and drive roots for the item cmdlets, several accounts or a Deny
entry without Synchronize for `Add-NTFSAccess`, and the `-ExcludeExplicit`,
`-ExcludeInherited`, and `-Account` filters of the audit reads with a
descriptor. They are open, with the table as the list of what would close
them; nothing is called harmless.

## Stage D: the environments

### Cultures

The C# calls whose result depends on the culture of the thread, found by a
text scan of the four projects (`ToLower`, `ToUpper`, `Compare`, `CompareTo`,
`StartsWith`, `EndsWith`, and `IndexOf` without a `StringComparison`; `Parse`;
`Convert`; number and date formatting):

| Where | Call | Verdict |
| --- | --- | --- |
| `Security2\IdentityReference2.cs`, `Equals(object)` | `ntAccount.Value.ToLower() == value.ToLower()` | a defect in `tr-TR`, fixed in `419cfb3` (below) |
| `NTFSSecurity\BaseCmdlets.cs`, path prefixes | `StartsWith("..\\")`, `".\\"`, `"./"`, `"\\"` | the culture overload, on ASCII punctuation: no difference in `de-DE` and `tr-TR`; characters that a culture ignores in a comparison (such as U+200B) were not probed |
| `AddAccess`, `RemoveAccess`, `AddAudit`, `RemoveAudit` | `ParameterSetName.StartsWith("Path")`, `EndsWith("Simple")` | the culture overload on ASCII names; the sets do not hold an uppercase `I`; no difference |
| `Security2\Win32\Lib.cs`, `Win32Lib.cs` | `AncestorName.StartsWith(@"\\?\")` | the culture overload on ASCII punctuation: no difference |
| `Security2\FileSystem\FileInfo\Extensions.cs` | `ToString("X2")` | hexadecimal digits: culture-invariant |
| `FileSystemSecurity2.cs`, `Lib.cs` (`IsLocalComputer`) | `OrdinalIgnoreCase`, `Ordinal` | not culture-sensitive |
| messages | `string.Format` with counts | Latin digits in `de-DE` and `tr-TR` |

The unit suite ran elevated in a child process per edition, with the current
culture and the current UI culture of the thread set to `de-DE` and `tr-TR`
(`Run-CultureSuite.ps1`, the CI wrapper `Invoke-Tests.ps1`, an uninstrumented
copy of the measured build):

| Culture | Edition | Cases | Failed | Skipped |
| --- | --- | ---: | ---: | ---: |
| `de-DE` | Windows PowerShell 5.1 | 1,314 | 0 | 24 |
| `de-DE` | PowerShell 7 | 1,314 | 6 | 55 |
| `tr-TR` | Windows PowerShell 5.1 | 1,314 | 0 | 24 |
| `tr-TR` | PowerShell 7 | 1,314 | 0 | 55 |

The six failures of `de-DE` in PowerShell 7 are assertions on English message
text, not defects of the module: PowerShell 7 localizes its message for a
failed parameter validation and quotes the parameter name as „Filter“, where
the tests match `'Filter'` or `'Title'` with ASCII quotes. They are the null
`-Filter` of `Get-ChildItem2` (`ItemCmdlets.Tests.ps1`, line 235) and the five
refused titles of `Invoke-TestsAsBasicUser.ps1` (`Repository.Tests.ps1`, lines
128 and 133). Each of them also asserts the error ID, which passes. The tests
stay as they are: CI runs the culture of its image, and weakening an assertion
to make a localized run green is not a gain.

The suite found no failure in `tr-TR`, but that does not say the culture is
safe: no test compared a name that holds an uppercase `I` with the same name in
another case. A probe did (`p-culture-identity.ps1`, both editions, a new
process each):

| Name | Culture | Equals exact | Equals lowercase | Equals uppercase |
| --- | --- | --- | --- | --- |
| `BUILTIN\Administrators` | `en-US` | True | True | True |
| `BUILTIN\Administrators` | `tr-TR` | True | **False** | **False** |
| `NT AUTHORITY\SYSTEM` | `tr-TR` | True | **False** | True |
| `NT AUTHORITY\INTERACTIVE` | `tr-TR` | True | **False** | True |

`$entry.Account -eq 'builtin\administrators'` is true in `en-US` and false in
`tr-TR`: the comparison lowercases both names with the culture of the thread,
and `tr-TR` turns `I` into U+0131. The cmdlets compare identities by SID, so
they are not affected; a script that compares the account of an entry with a
name is. The defect is reproducible, so by Decision 16 it is fixed: the test
`Should compare a name with the account ignoring case in Turkish, where I and i
are different letters` in `ObjectApis.Tests.ps1` sets the culture of the thread
to `tr-TR` and compares the system account with its name in three cases. Before
the fix it fails in all four configurations (1 failed of 110 rows in each,
`E\tdd\red`); after the one-line fix (`string.Equals` with `OrdinalIgnoreCase`)
it passes in all four (`E\tdd\green`). The change is a production change after
the tag, so it belongs to a new candidate that the maintainer decides on.

Not tested: a localized operating system (no such image exists: the ISO files
are English), the names of built-in accounts in other languages, and the
localized texts of Windows errors.

### Server Core

Not deployed: a new machine widens the proposed Decision 24, and the
maintainer's word is needed. The plan, with numbers measured on this host
where they exist:

- **Image.** `en-us_windows_server_2025_updated_april_2026_x64_dvd_225d826d.iso`
  (the ISO of `OSFile25`), index 3, `Windows Server 2025 Datacenter` (the
  Server Core installation; index 4 is the Desktop Experience installation that
  every matrix machine uses). The WIM image is 10.9 GB, against 23.6 GB for the
  Desktop Experience.
- **Disk.** The base image of the Desktop Experience of the same system is
  14.5 GB on `V:` and its differencing disk 3.6 GB after the runs; a Core
  base image is expected at 8 to 10 GB (an estimate from the ratio of the WIM
  images) and a differencing disk at about 3 GB. `V:` has 191 GB free of 991.9
  GB, so the machine costs about 12 GB.
- **Time.** The estimate is under an hour for the machine (the base image, the
  unattended installation, and the start; `Add-OsMatrixMachine.ps1` allows 40
  minutes for the start) plus a few minutes for the tools, and 10 to 15 minutes
  for a cell, like the other cells. It was not measured.
- **Commands.** In an elevated Windows PowerShell 5.1 on the host, in this
  order, never together with a controller or another `Import-Lab`:

  ```powershell
  .\Tests\Lab\Acceptance\Add-OsMatrixMachine.ps1 -LogPath $env:TEMP\add-oscore25.log `
      -Name OSCore25 -OperatingSystem 'Windows Server 2025 Datacenter' `
      -IpAddress 192.168.12.26
  .\Tests\Lab\Acceptance\Complete-OsMatrixLab.ps1 -LogPath $env:TEMP\complete-oscore25.log `
      -Member OSCore25
  ```

  Then, with the extracted candidate folder as `<module>`:

  ```powershell
  .\Tests\Lab\Acceptance\Run-MatrixLocalSuite.ps1 -Label core1 -Machine OSCore25 `
      -ModulePath <module> -OutputRoot <folder> -Mode Elevated,Basic
  .\Tests\Lab\Acceptance\Run-MatrixSequence.ps1 -Label core1 -FileServer OSCore25 `
      -ModulePath <module> -OutputRoot <folder> `
      -Machines OSFile19,OSFile22,OSFile25,OSCore25,OSWin11E
  ```

  with `OSWin11E` started shortly before the sequence (it shuts down an hour
  after its start), and `Test-MatrixCleanup.ps1 -Mode Verify -Machine
  OSFile19,OSFile22,OSFile25,OSCore25,OSWin11E` after it. The address
  `192.168.12.26` is not in the hosts file of the host (the matrix lab uses
  .10, .11, .12, .19, .22, and .25).
- **What it can find.** Server Core has no shell and no Desktop Experience
  components; the module is .NET Framework 4.5.2 code with Win32 calls, so a
  difference would show in the import, in AlphaFS, or in the privilege code. It
  can not find a difference of a localized system.

### ARM64

No reproduction exists. The crash of PowerShell 7.6.1 under x64 emulation had
no module frames, and native x64 CI did not reproduce it (`progress.md`, open
item 5). It stays open.

## Final measurement

The code and the tests of the work are frozen at the commit
`b2cb47b5a0b21c8390aef7a71b82b86610296d56` of `ai/coverage-unknowns` (the fix
`419cfb3`, the four test files, one change of the list of the suite of the
matrix lab, and one of a test). It was measured like `fa0701b`, in a new
frozen worktree and with the same commands (`Run-Frozen.ps1`: Build, Validate,
then Coverage), and its skip eligibility was checked on a second, uninstrumented
tree that holds the same bytes (every file hash-equal to the pristine copy of
the build). Against `fa0701b` the production code differs in one statement
(`IdentityReference2.Equals`), and the tests grew by 141 rows.

- Build: Release, 0 errors, 317 warnings (296 of CS1591, 19 of CS1574, one of
  CS0169, one of CS0618), the same as at `fa0701b`.
- Validate (no instrumentation): 1,455 cases in each of the four
  configurations, no failure.

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,429 | 0 | 26 | 1,455 |
| Windows PowerShell 5.1, basic user | 1,179 | 0 | 276 | 1,455 |
| PowerShell 7, elevated | 1,398 | 0 | 57 | 1,455 |
| PowerShell 7, basic user | 1,148 | 0 | 307 | 1,455 |

- Skip eligibility, by row: 666 skipped rows of 165 distinct tests (582 and
  138 at `fa0701b`); every skipped row executes in two other configurations,
  and no skipped row lacks an executed counterpart. The 84 skipped rows that
  are new are 80 rows of the two basic-user configurations (they need the
  Security, Restore, or symbolic-link privilege, or an owner that a basic user
  does not hold by default) and 4 rows of the two elevated ones (the test of
  the error without the Security privilege, and the test of a denied read that
  the Backup privilege would bypass).
- The instrumented runs gave the same counts. The measured assemblies:

| Assembly | SHA-256 |
| --- | --- |
| `NTFSSecurity.dll` | `DB725D529E6F89BD207DE673BE4A655FF1F1988DFB23981BC33117C52821D312` |
| `Security2.dll` | `487DBEF7690B33A85285F27D9596A924EFE9A8292ED02FE5F6B6F456CD323D6D` |
| `ProcessPrivileges.dll` | `19B35D2A9180BB5E09F078DCCDB6E47F5817DAF2929A972E17C1312475D1AC3A` |
| `PrivilegeControl.dll` | `37A6527173D5DE05E3D81D733951742A1D788DBA632239A01158F22F0FB524E3` |

| Assembly | Sequence points | Sequence coverage | Branch points | Branch coverage |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 1,957/2,168 | 90.27% | 683/1,094 | 62.43% |
| Security2 | 1,061/1,240 | 85.56% | 509/753 | 67.59% |
| ProcessPrivileges | 205/219 | 93.61% | 72/125 | 57.60% |
| PrivilegeControl | 20/22 | 90.91% | 12/17 | 70.59% |
| Aggregate | 3,243/3,649 | 88.87% | 1,276/1,989 | 64.15% |

The explicit branch points that a person wrote are 1,090/1,168 (93.32%), as at
`fa0701b`. The 45 added sequence points are the getters described in Stage C.
The per cmdlet table ([the Cmdlets CSV](Quality-Gate-Unknowns-2026-10-10-Cmdlets.csv),
the unit suite of the host at `fa0701b`, the domain member, the first lab, the
final unit suite, and all sources together) has 19 cmdlets with more visited
points at the final commit; every cmdlet has 76.5% or more of its sequence
points visited by the sources together (72.5% for the unit suite of `fa0701b`),
and the lowest are `Clear-NTFSAudit` and the two audit inheritance cmdlets,
whose ownership-retry closures stay unvisited.
The final build is another build of the same source and has other hashes than
the build of Stage A (the Release build is not byte-reproducible), so the two
measurements are compared by method and by position, not by hash.

The unvisited inventory of the final build has 187 methods, 406 sequence
points, and 78 explicit branch points; each of the 187 is classified (none is
unclassified), 167 as explained and 20 as open (the 8 methods that the paths
report left to the maintainer, and 12 getters of pipeline parameters).

## Decisions made

The decisions below are the agent's, taken inside the limits of the handoff;
the maintainer can reverse every one of them.

1. **The design of the live measurement.** The first design (`--portable`)
   failed on one role and is recorded with its evidence; the second (an
   absolute report path and a watcher) gave the counts of the acceptance. No
   third design was tried, as the handoff bounds the effort at two.
2. **The runs of the live suite.** One call of the unmodified controller per
   edition in the first lab, one per cell in the matrix lab with both editions
   in it, the cells one after the other, `OSWin11E` started last and used
   within the hour. The controller and the live tests are the files of the
   repository (Git blobs `635bf162…` and `efe36e50…`).
3. **The instrumented bytes.** The four input assemblies are the files that
   Stage A measured, and the zero-hit report has the points of Stage A, so the
   sources can be merged by position.
4. **Skip eligibility on a second tree.** Coverage instruments `bin\Release`
   in place, so the rows are discovered on an uninstrumented copy of the same
   bytes, at `fa0701b` and at the final commit.
5. **The tests of the domain-member suite.** The files of the frozen `fa0701b`
   worktree, not of this branch: the new test of `tr-TR` would fail against the
   build without the fix.
6. **The classification.** `WIN32-AUTHZ-FAILURE` was narrowed, four rules are
   new, and `CMDLET-GETTER` was corrected and split (Stage A and Stage C).
7. **Agents.** The judged matrix (four judges) and the writing of the tests
   (four implementers) were delegated, as they need much reading and
   writing; the controller checked the citations mechanically, ran the merged
   suite and the skip eligibility, read samples of the files, and asked each
   implementer for a strict status per set. The judges and the implementers
   are agents of the harness, not independent reviewers.
8. **The identity comparison** is a reproducible defect that is not an open
   item, so Decision 16 applies: a test that fails without the fix, the
   one-line fix, and a changelog entry. It stays a production change after the
   tag; whether it enters a new candidate is the maintainer's decision.
9. **The `de-DE` failures** (6, PowerShell 7) are assertions on English
   message text of PowerShell, and the tests stay as they are.
10. **The hard-link defect is not fixed** (Stage C): the fix chooses which
    names two cmdlets return and adds code to their path, which is a decision.
11. **Not pinned:** the four `MaintainerDecision` sets, and the behavior that a
    piped `AppliesTo` property does not select the Simple set.
12. **Stage C stopped** at 79 `It` blocks, the target of 15 to 20 per file;
    every remaining gap is in the ParameterSets table. The 12 getters were not
    tested, to keep the measured commit stable for the lab acceptance.
13. **Server Core, ARM64, and a localized system** were not tested (Stage D):
    no new machine without the maintainer's word, and no such image exists.
14. **No kit script.** The commands of the method are in this report, and the
    scripts of the session are named in the evidence; the handoff calls a kit
    welcome, not required.
15. **The suite of the matrix lab** runs the four new files from now on
    (`b2cb47b`), so that the next acceptance proves them on every machine.
16. **A rehearsal** of the final run on `ef45b38` (three of the four files)
    was stopped in the mode Coverage after Build and Validate had passed (1,407
    cases in each configuration), and replaced by the final run.

## Open items for the maintainer

New items of this work; the open items of the paths report (the `FileSecurity`
conversions, the `RemoveAll` filters, the lazy path overloads, the abandoned
`PrivilegeEnabler`, the dot rules of `Get-ChildItem2 -Filter`, the 17
owner-restore handlers, the unused classes, the swallowed initialization errors
of the effective-access check, Decisions 22 and 24, and #34) stay as they are.

1. **Hard-link names under a root that is not the volume root.** A defect with
   a reproduction (Stage C). Options: the names under the real volume root
   (a final path of a handle), the names under the root that the caller gave,
   or a documented limit. The call of `repro.ps1` is the regression test.
2. **`AUDIT-OWNER-RETRY` and `AUDIT-READ-DENIED`** (47 plus 6 sequence points)
   have no trigger on a Windows file server. Closing them needs an answer of a
   file server that is not a Windows server (#34), or a seam that injects the
   exception (a design change).
3. **A piped property `AppliesTo`** does not select the Simple set of
   `Add-NTFSAccess` and `Remove-NTFSAccess` and is dropped without a message.
   Intended or not?
4. **Twelve getters of pipeline parameters** that take pipeline input by
   property name and that no test supplies on a piped object (Stage C lists
   them): tests close them.
5. **The remaining gaps of 52 sets** in the ParameterSets table (68 `budget`,
   16 `Limit`, 3 `would-pin`), and the four `MaintainerDecision` sets with the
   open item 1 of the paths report. The `-SecurityDescriptor` sets other than
   three were not tested with a direct call that passes several descriptors.
6. **A new candidate.** The fix `419cfb3` and the tests are changes after the
   tag; a new candidate, if he takes them, needs the acceptance (matrix cells
   and first lab) on its own bytes. The acceptance of the fixed build below is
   evidence for the behavior, not for a release.
7. **Server Core** (the plan of Stage D; it widens the proposed Decision 24),
   **ARM64**, **a localized operating system** (names of built-in accounts and
   error texts), and **non-Windows file servers**.
8. **A trivial observation:** `RemoveAudit.cs` converts the scope of an
   `-AppliesTo` twice for the set `PathSimple` (at the top of `ProcessRecord`
   and again in the loop). It is idempotent and has no effect.

## Completion matrix

| Unknown | Status | Evidence |
| --- | --- | --- |
| Coverage of the shipped code (rc7, `fa0701b`) | Closed | Stage A: 3,198/3,649 sequence points (87.64%), 1,090/1,168 explicit branch points; 232 methods classified, none unclassified; the Methods, Cmdlets, and Reconciliation tables |
| Coverage of the live tests | Closed | Stage B: first lab and three matrix cells, 245 and 229 passed per edition, the counts of the uninstrumented acceptance; 1,861 sequence points each, 9 sequence and 4 explicit branch points more than the host unit suite; the cells add nothing to the first lab |
| The unit suite on a domain member | Closed | `OSFile25`, four configurations, the counts of the rc7 acceptance; 9 sequence and 3 explicit branch points more than the host |
| The code of `fdd7a8b` | Closed, with one branch visited by nothing | the ServerAdmin tests (lines 478 and 486) and the basic-user runs on the domain member visit the fall back; the answer "RPC server unavailable" of the context initialization is visited by nothing (explained) |
| `AUDIT-OWNER-RETRY`, `AUDIT-READ-DENIED` | Open | no test visits them; no trigger on a Windows file server (probe of 48 calls); closing needs a non-Windows server (#34) or a seam |
| The reachable gaps, the judged matrix of the 64 parameter sets | Partly closed | 79 `It` blocks (140 rows), 33 of 35 mutations caught; 7 sets closed, 51 partly, 1 open, 4 `MaintainerDecision`, 1 `None`; 12 getters of pipeline parameters open; one defect (hard-link names) and one behavior (piped `AppliesTo`) for the maintainer |
| Other cultures | Closed for `de-DE` and `tr-TR` | one defect found and fixed test-first (`419cfb3`); six `de-DE` failures are assertions on English text; localized names and texts untested |
| Windows Server Core | Open | a plan with the image index, disk, time, and commands; deploying needs the maintainer's word |
| ARM64 | Open | no reproduction |
| The final commit | Closed | `b2cb47b`: 1,455 cases per configuration, no failure; 3,243/3,649 sequence points (88.87%); eligibility by row; 187 unvisited methods classified |
| The lab acceptance of the fixed build | see the section below | the first lab, both editions, with the package of the measured bytes |

## Checks not run, and limits

- A coverage percentage counts visited points, not assertions: the mutation
  proofs (35) test the new tests, and the 7 closed sets of the matrix are the
  ones whose named gaps are asserted. The coverage of the unit suite barely
  moved (+45 points, all getters), because the gaps were assertions and not
  lines.
- The live coverage ran on one first lab and three cells of the matrix lab
  with one client (`OSWin11E`); the matrix cells added no point, so the claim
  that the operating system does not change the code that the tests run
  rests on those three server versions and one client.
- The unit suite ran on a domain member in the 18 behavior files that
  `Run-MatrixLocalSuite.ps1` stages (1,011 of 1,314 cases), not in the files
  that check the repository, the manifest, the help, the wiki, and the release
  scripts, which need the repository.
- Not run: a hard link through a volume mounted into a folder or through a
  junction to another volume (the defect is reproduced with a substituted
  drive only); the 12 getters; the matrix suite on `OSWin11E` and `OSWin11`
  with the new files; Windows Server Core; ARM64; a localized operating
  system; a file server that is not a Windows server.
- The Release build is not byte-reproducible: a hash identifies the measured
  files, not the source. Different code has different denominators; the
  measurements of `5a5d58b`, `fa0701b`, and `b2cb47b` are not increments of
  one source, and the comparison is by method and position.
- The custom `security-reviewer` cannot start (its model is unavailable), and
  no model setting was overridden; the independent review below is the
  read-only built-in `code-review` agent.
- Nothing was pushed, merged, tagged, or published. The stable 5.0.0 stays
  gated by the other gates, and a percentage never closes a gate.

## Evidence outside git

The raw evidence is in the session folder
`C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns`
(`E` above). [The Evidence CSV](Quality-Gate-Unknowns-2026-10-10-Evidence.csv)
lists its files with size and SHA-256; the folders are:

| Folder | Content |
| --- | --- |
| `fa0701b`, `eligibility-fa0701b`, `inventory-fa0701b`, `classification-fa0701b.csv`, `reconciliation-fa0701b.csv` | Stage A: the frozen worktree, the reports and logs of the four configurations, the pristine and saved assemblies with hashes, the skip rows, and the inventory |
| `live-inst2`, `live-fl1b`, `live-fl2`, `localsuite-osfile25`, `live-matrix`, `probe-auditdenied` | Stage B: the instrumented module and its zero-hit report, the rejected first design, the first lab, the unit suite on the domain member, the matrix cells, and the audit probe, each with the report, the snapshots per process, the validation, and the logs |
| `paramsets`, `impl` | Stage C: the scan, the judged tables and notes, the status tables, and the run logs of the implementers |
| `cultures`, `probes`, `tdd` | Stage D and the fix of the identity comparison: the four culture runs, the probes (`hardlink-root` has the reproduction), and the red and green runs |
| `final`, `eligibility-final`, `inventory-final`, `classification-final.csv` | the final measurement and its package |
| `live-fix1`, `localsuite-final`, `chain-fix.log` | the lab acceptance of the fixed build |
| `merge`, `scripts` | the merged points by position, and every script of the method |

Nothing in the evidence holds a password; the controller keeps them in memory.
