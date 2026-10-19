# Quality gate, the coverage unknowns, 2026-10-10

Handoff 5 of the quality gate before 5.0.0 (Decision 21). Handoff 1 measured
the C# coverage of the unit suite at `5a5d58b` and explained the unvisited
paths from source; an explanation is not a test. This report measures what
was still unmeasured and tests what the new numbers show. It does not close
the gate: the stable 5.0.0 stays blocked, the open items of the
[paths report](Quality-Gate-Paths-2026-10-09.md) stay with the maintainer, and
a coverage percentage never closes a gate. The agent pushed, merged, tagged,
and published nothing; the maintainer pushed the branch himself (`2b97422` on
2026-10-11).

The work is on `ai/coverage-unknowns`, from `origin/master` at `6696f68`
(PR #123). Every stage is described below; the
[completion matrix](#completion-matrix) says which unknown is closed and which
is open.

## Result in short

- **The shipped code.** The unit suite of the host visits 3,198 of 3,649
  sequence points (87.64%) of rc7 (`fa0701b`) and 1,090 of 1,168 explicit
  branch points (93.32%). All 232 unvisited methods are classified. The branch
  summary of the tool (64.15%) adds points that no person wrote, and it is not
  read here (Coverage of the shipped code).
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
  corrects an explanation of the paths report. On the file servers of the
  matrix lab, one new test failed in every elevated configuration of the first
  run because of its oracle (`Get-Acl -Audit` reads the SACL of an item
  without audit entries as protected on a domain member; the module was
  right); five assertions now read the SACL alone (`f1f3d8f`). The fix of the
  piped `AppliesTo` adds 22 `It` blocks (33 rows) to the two ParameterSets
  files. At the final commit `2112ee3`, whose product code was built once (at
  `9783d2a`), the suite has 1,492 cases per configuration without a failure and
  covers 3,266 of 3,668 sequence points (89.04%); 183 methods stay unvisited,
  all classified (at the earlier commit `61e936e`: 1,459 cases, 3,258 of 3,664
  points, 187 methods).
- **The acceptance of the final package in the labs.** The package is the
  Release build of `9783d2a` with the help file of `7bc7925`; the four
  assemblies are the ones that the first lab accepted. The first lab passed
  245, 0 failed, 1 skipped in each edition (`ap7`). The unit suite passed in
  all 16 configurations on the three file servers and on the Windows 11
  client, 1,189 cases each (`ap8`). The three cells of the matrix lab passed
  229, 0 failed, 2 skipped in each edition (`ap8`; the first start of the
  cells, with the command that I had given the maintainer, did nothing because
  it did not set the module path, see the section on the acceptance). Every end
  state was `CLEAN`. This is acceptance of the behavior on these bytes, not of a
  release.
- **Three defects fixed, one open.** Two comparisons were wrong in `tr-TR`, and
  both are fixed test-first: an identity compared with a name by `Equals`
  (`419cfb3`), and `Get-ChildItem2 -Filter` (`0028ccd`, `fbe0289`, `8a625c8`),
  which the independent review found after the first scan had missed its class
  of call. The third is the piped `AppliesTo`: a path dropped the property
  without a message, because the cmdlets declared a default parameter set. The
  maintainer decided to fix it, and it is fixed test-first (`93ed2c7`). The
  third independent review found that this fix let the scope of a piped
  object reach the next one, a defect that rc7 has for piped
  `-SecurityDescriptor` objects too; it is fixed in `9783d2a`. The check of
  that fix found a false sentence in the documents: only a `$null` `AppliesTo`
  fails to bind, while a value that PowerShell cannot convert to a scope (a
  blank CSV cell, a misspelled name) is ignored, and the object is handled as
  one without `AppliesTo`, silently (open item 3). `7bc7925` corrected the
  words and the tests; a second check found the sentence still too narrow (the
  object then uses its own flags before it gets the default scope, and a CSV
  row with fewer fields than its header gives `$null`), and `2112ee3` corrects
  it again. The hard-link
  cmdlets (`New-NTFSHardLink -PassThru`, `Get-NTFSHardLink`) fail for a path
  whose root is not the volume root; the defect is reproduced and left to the
  maintainer.
- **The reviews.** Three independent reviews and two follow-up checks of the
  third reviewer read the work, all by the built-in `code-review` agent. The
  first review found four Major findings and several Minor ones; each was
  resolved, three of the Major ones after a probe (the claim about `-eq` was
  wrong, the filter defect was real, the audit tests of a piped `AppliesTo`
  did not bind the set that they named). The second found five Minor findings
  in tests and documents. The third, of the `AppliesTo` fix, found one Major
  defect of the fix and two Minor findings. Its first check of the correction
  found one more Major finding (the false sentence above) and one Minor
  finding; its second check, of `7bc7925` and of this report, found seven
  Minor findings and no Major. Each finding was resolved (the section on the
  fix and the section Review). The last commits carry the words and the test
  titles that the second check asked for; runs verified them, and no agent
  read them again.
- **Environments.** `de-DE` and `tr-TR` are tested. Server Core, ARM64, a
  localized operating system, and non-Windows file servers are out of scope:
  the maintainer decided on 2026-10-11 that the audience of the tool does not
  need them (decision 22 below, Memory Bank Decision 25).

## Tables

| File | Content |
| --- | --- |
| [Methods](Quality-Gate-Unknowns-2026-10-10-Methods.csv) | the 232 unvisited methods of `fa0701b` with the rule, the category, the disposition, and what the other sources and the build of `b2cb47b` visit |
| [Cmdlets](Quality-Gate-Unknowns-2026-10-10-Cmdlets.csv) | per cmdlet, the visited sequence and explicit branch points of each source (the final column is the build of `b2cb47b`; see Final measurement) |
| [Reconciliation](Quality-Gate-Unknowns-2026-10-10-Reconciliation.csv) | the 232 methods against the 231 of `5a5d58b` |
| [ParameterSets](Quality-Gate-Unknowns-2026-10-10-ParameterSets.csv) | the judged matrix of the 64 sets and its status after the new tests; the cited file:line references point at the tests of the final commit (mapped through the hunks of `git diff` from `fa0701b`, and for the new files from the commit that added each; a line that the free text of `Gap` and `Evidence` names without a file name is not mapped); the column `Default` is the declaration of rc7 (the four `PathComplex` sets of the Add and Remove cmdlets for access and audit lost their default in `93ed2c7`) |
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
| Security2 | 1,061/1,240 | 85.56% | 509/753 | 67.60% |
| ProcessPrivileges | 205/219 | 93.61% | 72/125 | 57.60% |
| PrivilegeControl | 20/22 | 90.91% | 12/17 | 70.59% |
| Aggregate | 3,198/3,649 | 87.64% | 1,276/1,989 | 64.15% |

The ratios are visited sequence or branch points divided by their totals, not
unique source lines. The branch summary of the tool is not a count of the
branches that a person wrote: it has 821 points more than the 1,168 explicit
branch points, and they are not patterns such as `foreach` and `using`, as the
paths report described them. The tool adds one point to each of the 198 methods
that have explicit branch points, which it counts as visited when the method
runs (186 of the 198 did), and one point to each of the 623 methods that have
none, which it never counts as visited, although 456 of those methods run
(`inventory-fa0701b\branch-summary-decomposition.txt`, read from the summary of
every method in the report). The summary percentage therefore falls when a
method without a branch is added; this report reads the explicit branch
points, 1,090/1,168 (93.32%).

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

After Stages A and B, all 232 unvisited methods of the host unit suite are
classified (451 sequence points); 167 have a source-backed explanation and 65
do not (the 8 methods of the open items of the paths report, and 57 getters of
pipeline parameters that PowerShell reads and that no test supplied), and 9 of
the 451 points are now visited on a domain member and in the lab. What a point
count does not show is whether the parameter sets are tested as behavior. So
this stage tests the matrix, not the numbers.

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

The new tests add 45 sequence points and no explicit branch point. At
`b2cb47b`, the build of the tests, the unit suite of the host visits 3,243 of
3,649 sequence points (88.87%), against 3,198 (87.64%) at rc7; every one of the
45 points is a getter of a cmdlet parameter in `NTFSSecurity.dll` (1,912 to
1,957 of 2,168 points, 88.19% to 90.27%); the explicit branch points stay at
1,090 of 1,168 (93.32%). The reconciliation of the unvisited methods of the two
builds has 187 methods that are unchanged and 45 that are visited now; no
method is changed or new. The final build adds the fix of the filter (Final
measurement): 15 more sequence points, all visited, and the same 187 unvisited
methods, so it visits 3,258 of 3,664 sequence points (88.92%).

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
  change of the output of two cmdlets for the maintainer. The failing calls are
  the regression test for the fix. With the final package they behave as
  follows in both editions (`E\probes\hardlink-root\repro-minimal.ps1`, with
  the outputs `repro-minimal-final4-Desktop.txt` and
  `repro-minimal-final4-Core.txt`, which equal those of the package of
  `b2cb47b`; the first reproduction, `repro.ps1`, ran in the worktree of the
  implementer):

  ```powershell
  $folder = Join-Path -Path $env:TEMP -ChildPath ('HardLinkRoot-{0}' -f [guid]::NewGuid().ToString('N').Substring(0, 8))
  $null = New-Item -ItemType Directory -Path $folder
  # The last drive letter that is free, so that no drive or SUBST mapping of yours is touched
  $letter = 90..68 | ForEach-Object -Process { [char] $_ } | Where-Object -FilterScript { -not (Test-Path -LiteralPath ('{0}:\' -f $_)) } | Select-Object -First 1
  $root = '{0}:\' -f $letter
  subst.exe ('{0}:' -f $letter) $folder
  try {
      Set-Content -LiteralPath "${root}Target.txt" -Value 'Target'
      try {
          # A terminating FileNotFoundException; the link exists on disk
          New-NTFSHardLink -Path "${root}Link.txt" -Target "${root}Target.txt" -PassThru
      }
      catch { $_.Exception.Message }
      # Writes FileNotFound for a file that exists
      Get-NTFSHardLink -Path "${root}Target.txt"
  }
  finally {
      subst.exe ('{0}:' -f $letter) /d
      Remove-Item -LiteralPath $folder -Recurse -Force
  }
  ```

- **A piped property did not select the Simple set of a path (fixed).** An
  object with the properties `FullName`, `Account`, `AccessRights`, and
  `AppliesTo`, piped into `Add-NTFSAccess`, `Remove-NTFSAccess`,
  `Add-NTFSAudit`, or `Remove-NTFSAudit`, did not bind `PathSimple`: the
  mandatory parameters of the default set `PathComplex` were satisfiable from
  the same object, so PowerShell settled on the default set before it tried
  the property, and the property was dropped without a message; an added entry
  got the default scope (`ContainerInherit, ObjectInherit`). The first probe
  ran in both editions on
  the package of `0028ccd` (`E\probes\review2-*.txt`; the binding code is not
  part of the later changes) and told the set for the first three cmdlets; for
  `Remove-NTFSAudit` the entries that remained were the same with and without
  the property, so it did not tell. A second probe on the final package, in
  both editions, uses one audit entry of the default scope, which the two sets
  treat differently: removing the scope `ThisFolderOnly` from it leaves the
  entry for the subfolders and files (`InheritOnly`), and removing the default
  scope removes it whole. The piped property removed it whole, like a call
  without `AppliesTo`, so `PathComplex` bound; a named
  `-AppliesTo ThisFolderOnly` left the `InheritOnly` entry
  (`E\probes\p-remove-audit-appliesto.ps1`, outputs
  `remove-audit-appliesto-Desktop.txt` and `-Core.txt`). For a descriptor, the
  property did select `SDSimple` in the real cmdlets of both editions: both
  Add cmdlets gave the scope `None`, and `Remove-NTFSAudit` left the
  `InheritOnly` entry. A stand-alone model of the binder (the section on the
  fix) binds `PathComplex` for such an object, so the model does not explain
  that case, which the real cmdlets show; its mechanism is not explained here.
  The judged
  notes had assumed the opposite for paths, and the first audit tests named
  rows `PathSimple` that piped the property, so they bound `PathComplex` and
  could not tell the sets; the independent review caught the contradiction with
  the access tests, and the rows named `-AppliesTo` and asserted the scope
  (`61e936e`).

  The maintainer decided on 2026-10-11 to fix it (decision 23): the section
  [The fix of the piped `AppliesTo`](#the-fix-of-the-piped-appliesto) has the
  change, the tests, the third independent review, which found a defect of the
  first fix, the measurement, and the acceptance.
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

The remaining items of the 57 sets that are not closed (51 partly closed, 1
open, 4 `MaintainerDecision`, and 1 `None`) carry one of four reasons, counted
by mention: 68 `budget` (the implementer stopped at the
target of 15 to 20 blocks per file; plain test work that needs no decision and
no lab), 16 `Limit` (a remote file server or a lab is needed, such as the owner
retry of an audit write or a `PermissionDenied` category), 7
`MaintainerDecision` (open item 1 of the paths report), and 3 `would-pin` (a
test would pin a behavior that a maintainer may change). Of the 52 partly
closed or open sets alone the mentions are 62, 16, 3, and 2. 32 sets have only
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
`Convert`; number and date formatting). The first scan missed one class of
call, a case-insensitive `WildcardPattern` or `Regex` without `CultureInvariant`;
the independent review found the one that matters (below), and a second scan
for `WildcardPattern`, `Regex`, `IgnoreCase`, and `CultureInfo` found no other:

| Where | Call | Verdict |
| --- | --- | --- |
| `Security2\IdentityReference2.cs`, `Equals(object)` | `ntAccount.Value.ToLower() == value.ToLower()` | a defect in `tr-TR`, fixed in `419cfb3` (below) |
| `NTFSSecurity\ItemCmdlets\GetChildItem2.cs`, the filter | `new WildcardPattern(..., IgnoreCase)`, and the enumeration of AlphaFS 2.2, which matches the filter with a case-insensitive regular expression | a defect in `tr-TR`, found by the review, fixed in `0028ccd`, `fbe0289`, and `8a625c8` (below) |
| `Security2\IdentityReference2.cs`, line 9 | `new Regex("(S-1-)[0-9-]+", RegexOptions.IgnoreCase)` | ASCII digits and hyphens: no difference |
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
`-Filter` of `Get-ChildItem2` (`ItemCmdlets.Tests.ps1`, line 235 at `fa0701b`)
and the five refused titles of `Invoke-TestsAsBasicUser.ps1`
(`Repository.Tests.ps1`, lines 128 and 133). The test of the null `-Filter`
also asserts the error ID, which passes; the five refused titles assert only
the message, and the log shows the same validation error. The tests
stay as they are: CI runs the culture of its image, and weakening an assertion
to make a localized run green is not a gain.

The suite found no failure in `tr-TR`, but that does not say the culture is
safe: no test compared a name that holds an uppercase `I` with the same name in
another case, and none filtered by such a name. A probe did for the identity
(`p-culture-identity.ps1`, both editions, a new process each); the independent
review found the filter (below):

| Name | Culture | Equals exact | Equals lowercase | Equals uppercase |
| --- | --- | --- | --- | --- |
| `BUILTIN\Administrators` | `en-US` | True | True | True |
| `BUILTIN\Administrators` | `tr-TR` | True | **False** | **False** |
| `NT AUTHORITY\SYSTEM` | `tr-TR` | True | **False** | True |
| `NT AUTHORITY\INTERACTIVE` | `tr-TR` | True | **False** | True |

`$entry.Account.Equals('builtin\administrators')` is true in `en-US` and false
in `tr-TR`: the method lowercases both names with the culture of the thread, and
`tr-TR` turns `I` into U+0131. The operators are not affected. The first
version of this report and of the changelog entry named `-eq`, which the
independent review doubted; a probe on the previous build under `tr-TR`
(`E\probes\review-prefix-Desktop.txt` and `-Core.txt`) shows that `-eq`,
`-contains`, and `-in` return True for the exact, the lowercase, and the
uppercase name: PowerShell converts the name to an identity (`-as` gives a
`Security2.IdentityReference2`) and compares the two identities, which is
culture independent (`E\probes\p-eq-mechanism.ps1`, run on the bytes of rc7,
which have the code from before the fix; the outputs are
`eq-mechanism-Desktop.txt` and `-Core.txt`). The cmdlets compare identities by
SID, so they are not affected either; a script or a program that calls
`Equals` with a name is. The defect is reproducible, so by Decision 16 it is
fixed: the test
`Should compare a name with the account ignoring case in Turkish, where I and i
are different letters` in `ObjectApis.Tests.ps1` sets the culture of the thread
to `tr-TR` and compares the system account with its name in three cases. Before
the fix it fails in all four configurations (1 failed of 110 rows in each,
`E\tdd\red`); after the one-line fix (`string.Equals` with `OrdinalIgnoreCase`)
it passes in all four (`E\tdd\green`). The change is a production change after
the tag, so it belongs to a new candidate that the maintainer decides on.

### A second defect, found by the independent review

The scan listed the string functions and not the case-insensitive pattern
classes, so it missed `Get-ChildItem2 -Filter`. The reviewer read
`GetChildItem2.cs`, where a `WildcardPattern` compares each name with the filter
with `IgnoreCase` and without `CultureInvariant`, and asked for a probe. Under
`tr-TR` the previous build drops the items whose names differ from the filter in
the case of an `I`, in both editions (`E\probes\review-prefix-*.txt`;
`Get-ChildItem` is the reference):

| `-Filter` | `Get-ChildItem2` | `Get-ChildItem` |
| --- | --- | --- |
| `index*` | nothing | `Index.txt` |
| `INDEX*` | `Index.txt` | `Index.txt` |
| `*.ini` | `desktop.ini` | `desktop.ini`, `SETTINGS.INI` |
| `*.INI` | `SETTINGS.INI` | `desktop.ini`, `SETTINGS.INI` |

The defect is reproducible and not an open item (the dot rules of `-Filter` are
a different question), so by Decision 16 it is fixed test-first. The test
`Should match -Filter <Filter> ignoring case in Turkish, where I and i are
different letters` in `ItemCmdlets.Tests.ps1` sets the culture of the thread to
`tr-TR` and lists a folder with `Index.txt`, `desktop.ini`, `SETTINGS.INI`, and
`Other.txt`. On the previous build it fails in the four configurations (3 of 134
cases: `index*`, `*.ini`, and `*.INI`; `INDEX*` is the control; `E\tdd2\red`).

The first fix was not enough, which the probes showed. `0028ccd` made the
pattern of the cmdlet culture invariant (`WildcardOptions.CultureInvariant`: a
`WildcardPattern` without the option does not match `Index.txt` with `index*` in
`tr-TR`, and with it does, in both editions; `E\probes\wildcard-culture-*.txt`),
and the test still failed on that build. The enumeration also compares with the
culture: AlphaFS 2.2 matches the filter with a regular expression that takes the
culture of the thread, and `Directory.EnumerateFileSystemEntries` of AlphaFS
returns nothing for `index*` under `tr-TR`, where .NET returns `Index.txt`
(`E\probes\alphafs-filter-*.txt`; the same call in `en-US` agrees with .NET).
The fix has two parts: the pattern of the cmdlet is culture invariant, and the
enumeration, that is the creation of the enumerator and every `MoveNext`, runs
with the invariant culture (`fbe0289` and `8a625c8`), which is restored before
an item reaches the pipeline, so that no later command sees it. No other cmdlet
passes a pattern of the user to AlphaFS. On the fixed build `Get-ChildItem2`
returns the same names as `Get-ChildItem` for the four filters and two more, in
both editions, in `tr-TR` and in `en-US` (`E\probes\review-final4-*.txt`), and
the test passes in the four configurations (`E\tdd2\green3`: 200 cases of three
files, elevated and as a basic user).

Not tested, and out of scope by the decision below: a localized operating
system (no such image exists: the ISO files are English), the names of built-in
accounts in other languages, and the localized texts of Windows errors. The
review found one test that depends on a localized text, the comparison of
`Get-Privileges` with the State column of `whoami /priv` in
`ParameterSets.Items.Tests.ps1`; it compares the state now only where `whoami`
prints the English words.

### Out of scope: Server Core, ARM64, a localized system, non-Windows servers

The maintainer decided on 2026-10-11 to forget these four environments: the
audience of the tool does not need them, so they are not open items, and no
plan, deployment, or test of this work covers them (decision 22 below, Memory
Bank Decision 25). The Server Core plan that this section had
(image index 3 of the Server 2025 ISO, about 12 GB, under an hour for the
machine) was dropped with the decision and stays in the history of this file;
nothing was deployed. The ARM64 crash of PowerShell 7.6.1 under x64 emulation
had no module frames and was never reproduced on native x64.

## Final measurement

The code and the tests of the work were frozen at the commit
`61e936e80fd307cdc341a893c4afbbd155986756` of `ai/coverage-unknowns` for the
measurement below; the fix of the piped `AppliesTo` came after it (the section
on the fix, with its measurement of `9783d2a`, built once, and of `7bc7925` and
`2112ee3` on the same product bytes), and the commits after `2112ee3` change
documents only. Against
`fa0701b` the production code at `61e936e`
differs in two classes (`IdentityReference2.Equals`, and the filter of
`Get-ChildItem2`), and the tests grew by 145 rows. The measurement was made
three times, in a new frozen worktree each time and with the same commands:

1. **`b2cb47b`** (`b2cb47b5a0b21c8390aef7a71b82b86610296d56`: the fix
   `419cfb3`, the four test files, one change of the list of the suite of the
   matrix lab, and one of a test) was built and measured like `fa0701b`
   (`Run-Frozen.ps1`: Build, Validate, then Coverage). Its skip eligibility was
   checked on a second, uninstrumented tree that holds the same bytes (every
   file hash-equal to the pristine copy of the build). The first lab
   acceptance of the fixed build (`fix1`) and the first run of the unit suite
   on the file servers used the pristine package of this build.
2. **`f1f3d8f`** (`f1f3d8f0789f830f991c927197863456f74bf0fa`, the change of the
   oracle of five assertions that the file servers made necessary) was measured
   again on the same bytes, without a new build (`Chain-Remeasure.ps1`): a
   Release build is not byte-reproducible, and a new build would no longer be
   the build that the lab accepted. The 20 files of the pristine Release folder
   were copied into a new frozen worktree and a new eligibility worktree of the
   commit (all hashes equal), and the script refuses to run when a file outside
   the tests and the documents differs from `b2cb47b` (it does not). Validate,
   Coverage, and the skip eligibility were run again with the same commands.
3. **`61e936e`, the final measurement.** The independent review found the
   second culture defect (Stage D) after the two measurements above, and its
   fix changed the production code, so the build changed. The fix was built once
   at `8a625c8` (`E\final4`: Release, the same warnings; every file of the
   extracted package equals the pristine copy), and the test files of `61e936e`
   were measured on those bytes without another build (`Chain-Remeasure.ps1`,
   `E\final5`, the script again refusing to run if a file outside the tests and
   the documents differed from `8a625c8`; it does not). The first lab
   acceptance and the unit suite on the file servers and on the client at the
   end of this report ran on the package of this build; `fix1` to `fix3`, and
   the first run of the suite on the file servers, ran on the builds named with
   them.

The first two measurements gave the same results: 3,243 of 3,649 sequence
points, and of the 4,817 points (with the explicit branch points) none is
visited by one run and not by the other (`merge\final-vs-final2-points.csv`).
The final measurement differs from them in the code of one class, and is
shown here:

- Build (of `8a625c8`): Release, 0 errors, 317 warnings (296 of CS1591, 19 of
  CS1574, one of CS0169, one of CS0618), the same as at `fa0701b` and at
  `b2cb47b`.
- Validate (no instrumentation): 1,459 cases in each of the four
  configurations, no failure (1,455 at the first two measurements; the four new
  cases are the rows of the filter test).

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,433 | 0 | 26 | 1,459 |
| Windows PowerShell 5.1, basic user | 1,183 | 0 | 276 | 1,459 |
| PowerShell 7, elevated | 1,402 | 0 | 57 | 1,459 |
| PowerShell 7, basic user | 1,152 | 0 | 307 | 1,459 |

- Skip eligibility, by row: 666 skipped rows of 165 distinct tests (582 and
  138 at `fa0701b`); every skipped row executes in two other configurations,
  and no skipped row lacks an executed counterpart. The 84 skipped rows that
  are new are 80 rows of the two basic-user configurations (they need the
  Security, Restore, or symbolic-link privilege, or an owner that a basic user
  does not hold by default) and 4 rows of the two elevated ones (the test of
  the error without the Security privilege, and the test of a denied read that
  the Backup privilege would bypass). The skips are those of `b2cb47b` (666
  rows of 165 tests again, and no skip state changed): the four rows of the
  filter test are new and execute in all four configurations, and four audit
  rows have other data (they pass `-AppliesTo` by name now) with the same skip
  state (skipped as a basic user).
- The instrumented runs gave the same counts. The measured assemblies:

| Assembly | SHA-256 |
| --- | --- |
| `NTFSSecurity.dll` | `6A3F42391F7A2247EF0B722804DBFE09B7D52739275FE6D56D3E0448E381F806` |
| `Security2.dll` | `417FB25C40734FB20A686469C1A6BC1F0F3F5EE83F06BC7E4F447C53FF039542` |
| `ProcessPrivileges.dll` | `A3834E173905CCC664803B9642DE48C1D8AA0C97D25B3FE2AC02F4460EBFCBB9` |
| `PrivilegeControl.dll` | `826C0E6A643578E0739B8A7A0635482022E932172196F2F62A33D397E0ACBF0B` |

| Assembly | Sequence points | Sequence coverage | Branch points | Branch coverage |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 1,972/2,183 | 90.33% | 683/1,097 | 62.26% |
| Security2 | 1,061/1,240 | 85.56% | 509/753 | 67.60% |
| ProcessPrivileges | 205/219 | 93.61% | 72/125 | 57.60% |
| PrivilegeControl | 20/22 | 90.91% | 12/17 | 70.59% |
| Aggregate | 3,258/3,664 | 88.92% | 1,276/1,992 | 64.06% |

The explicit branch points that a person wrote are 1,090/1,168 (93.32%), as at
`fa0701b`. The final build visits 60 sequence points more than rc7: 45 are the
getters described in Stage C, and 15 are points of the new code of the filter
fix (the culture scope and its calls), all visited, so the denominator grew by
15. The branch summary grew by three points, one for each of the three new
methods, which it never counts as visited (Coverage of the shipped code: it
adds one point to a method without a branch), so its percentage fell from
64.15% to 64.06% while the explicit branch points did not change. All the new
points are in `GetChildItem2`: 148 of its 160 sequence points are visited (133
of 145 at `b2cb47b`), and 69 of its 70 explicit branch points (the same one as
at `fa0701b`, in the folder check of `WriteFileSystem`); the 12 unvisited
sequence points are the getters of its pipeline parameters.
The final build is another build of the same source and has other hashes than
the build of Stage A (the Release build is not byte-reproducible), so the
measurements are compared by method and by position, not by hash. Compared
with `f1f3d8f` by position (`merge\final2-vs-final5-points.csv`), none of the
4,602 points outside `GetChildItem2` is visited by one run and not by the other
and none is missing from one; the points of `GetChildItem2` cannot be aligned,
because its code changed and its lines moved (178 and 163 of the 393 positions
exist in one build only).

The merged tables of the sources, [Methods](Quality-Gate-Unknowns-2026-10-10-Methods.csv)
and [Cmdlets](Quality-Gate-Unknowns-2026-10-10-Cmdlets.csv) (the unit suite of
the host at `fa0701b`, the domain member, the first lab, the final unit suite,
and all sources together), are those of the measurement of `b2cb47b`: the other
sources ran the code of `fa0701b`, and the points of a method whose code
changed cannot be aligned by position with them, so the final column was not
rebuilt for the one changed class; it is given above. The table has 19 cmdlets
with more visited points at the final commit; every cmdlet has 76.5% or more
of its sequence points visited by the sources together (72.5% for the unit
suite of `fa0701b`), and the lowest are `Clear-NTFSAudit` and the two audit
inheritance cmdlets, whose ownership-retry closures stay unvisited.

The unvisited inventory of the final build has 187 methods, 406 sequence
points, and 78 explicit branch points, the same 187 methods as at `b2cb47b` and
at `f1f3d8f` (`GetChildItem2.WriteFileSystem` has 47 sequence points, all
visited, where it had 41); each is classified (none is unclassified), 167 as
explained and 20 as open (the 8 methods that the paths report left to the
maintainer, and 12 getters of pipeline parameters), with no row of the
classification changed (`classification-final5.csv`).

The measurement of `f1f3d8f` equals that of `b2cb47b`. Of the 4,817 points
(3,649 sequence points and 1,168 explicit branch points), none is visited by
one run and not by the other (`merge\final-vs-final2-points.csv`); the three
files of the inventory of the unvisited methods are byte-identical; and the
discovered rows and their skips are equal but for the line numbers of the rows
in the two edited test files. The coverage reports of two runs differ in hash,
as two runs do.

## Lab acceptance of the fixed build

A defect that is not an open item is fixed, and the lab acceptance of the
affected behavior is repeated on the fixed build (the handoff, as the paths
work did). It ran for each build that carried a fix, in the same way: the
unmodified controller and live tests of the repository (Git blobs `635bf162…`
and `efe36e50…`), the extracted package of the build (packaged like CI by
`New-ModulePackage.ps1` from the pristine copy and passed with `-ModulePath`),
no instrumentation, one call per edition (`Run-LiveAcceptance.ps1`) in
`WindowsAccessControlLab` (client `F1AFile1`, file server `F1AFile2`, four
domains, the trusts). Each run logs the hashes of the four assemblies at its
start.

| Run | Build (`NTFSSecurity.dll`) | Code that the fix changed | Clean end state |
| --- | --- | --- | --- |
| `fix1` | `b2cb47b` (`DB725D52…`) | the comparison of an identity with a name; no cmdlet uses it (the cmdlets compare identities by SID, and no line of the C# of the cmdlets compares an identity with a string) and no live test does | 21:30:18Z |
| `fix3` | `0028ccd` (`C0D10ED6…`), the first and incomplete fix of the filter; evidence, not final | the matcher of `Get-ChildItem2 -Filter` | 23:40:04Z |
| `fix4` | `8a625c8` (`6A3F4239…`), the final build, the bytes of the final measurement | the filter, complete: the culture scope around AlphaFS | 00:00:35Z |
| `ap7` | `9783d2a` (`DFA943D1…`; the package of `final7build`) | the four Add and Remove cmdlets of access and audit: no default parameter set, and the flags of a record in locals | 12:24:38Z |

The first run is evidence that the identity fix changes nothing in the lab. The
live tests do call `Get-ChildItem2` (a long path, `-Hidden`, the listing of a
share folder, a folder that the account cannot read, and `-Filter` on a share
folder), so `fix3` and `fix4` run the changed code in the three client roles,
over SMB, in `en-US`. They cannot show the `tr-TR` defect, which the unit tests
show; they show that the culture scope around the enumeration changes nothing
there. The live tests also call the four cmdlets of the fix of the piped
`AppliesTo` (17 calls: `Add-NTFSAccess` and `Remove-NTFSAccess`,
`Add-NTFSAudit` and `Remove-NTFSAudit`, with `-Path` and with
`-SecurityDescriptor`, with and without `-InheritanceFlags` and
`-AppliesTo`), so `ap7` shows that the removal of the default set changes no
named call in the lab, in any of the four roles. No live test pipes an object
into them; the unit tests show that. The acceptance ran on the package of
`9783d2a`; the package of `7bc7925` has the same four assemblies (the section
on the measurement of `7bc7925`), and the matrix cells and the suites below ran
on it. None of the runs is a release acceptance: a new candidate needs its own
(open item 6).

Per role (the same in all four runs and in both editions):

| Role | Account | Passed | Failed | Skipped | Exit code |
| --- | --- | ---: | ---: | ---: | ---: |
| Delegate | `A\NtfsLiveDelegate` | 69 | 0 | 0 | 0 |
| ServerAdmin | `A\NtfsLiveServerAdmin` | 36 | 0 | 0 | 0 |
| Admin | `A\NtfsLiveAdmin` | 64 | 0 | 0 | 0 |
| Server | `A\install` | 76 | 0 | 1 | 0 |

All four runs gave the same counts in both editions: 245 passed, 0 failed, 1
skipped (`LIVE_RESULT_VERIFIED`), the counts of the rc7 acceptance and of the
instrumented runs. The removal of the fixture and the independent check of the
end state found no account, share, folder, profile, task, or group member left
in the four domains and on both machines (`CLEAN` at the times above).

**The end state of both labs after the last run** (00:41 to 00:43Z,
`E\verify-final`). A read-only check of one lab after the other, with the
`Test-MatrixCleanup.ps1 -Mode Verify` of the kit and the SIDs of the last
fixtures, found no fixture, scheduled task, stage item, probe account, or
profile left: the matrix lab (the domain controller `OSDC1` and the file
servers `OSFile19`, `OSFile22`, and `OSFile25`) and the first lab (the four
domains, `F1AFile1`, and `F1AFile2`) are `CLEAN`. The Windows 11 client
`OSWin11`, which the kit does not check, was read with `Verify-Client.ps1`: no
scheduled task `NtfsMatrix*`, no stage item, no probe user or profile, no
share, and no folder or user of the fixture. `OSWin11E` had not been started,
and nothing in this work had run in it since the runs of Stage B.

**The cells of the matrix lab on the fixed builds.** The handoff accepts a fix
in the first lab; the matrix cells ran on the final build as well, because the
maintainer asked for them. A cell is one call of `Run-MatrixSequence.ps1`: the
evaluation client `OSWin11E` against one file server, both editions, the four
roles, the unmodified controller and live tests, and the extracted package of
the build. The first start of the cells, with the command that I had given the
maintainer, did nothing: started from a PowerShell 7 session,
`Start-Process powershell.exe` gives Windows PowerShell 5.1 the module path of
PowerShell 7, so `Get-FileHash` could not load, and the hidden window ended
without a log. The cells were started again from a process with the module
path of Windows PowerShell (the README of the lab kit says so now). They ran
twice, each time in sequence: on the package of `8a625c8` (`mxf`), and again on
the final package, after the fix of the piped `AppliesTo` (`ap8`):

| Run | Package | Cell | Start to end | Passed, failed, skipped per edition | Clean end state |
| --- | --- | --- | --- | --- | --- |
| `mxf` | `8a625c8` (`6A3F4239…`) | `OSFile19` | 07:33:10 to 07:40:10Z | 229, 0, 2 | 07:40:10Z |
| `mxf` | `8a625c8` (`6A3F4239…`) | `OSFile22` | 07:40:10 to 07:47:13Z | 229, 0, 2 | 07:47:13Z |
| `mxf` | `8a625c8` (`6A3F4239…`) | `OSFile25` | 07:47:13 to 07:56:57Z | 229, 0, 2 | 07:56:57Z |
| `ap8` | the final package (`DFA943D1…`) | `OSFile19` | 13:19:36 to 13:26:40Z | 229, 0, 2 | 13:26:40Z |
| `ap8` | the final package (`DFA943D1…`) | `OSFile22` | 13:26:40 to 13:33:22Z | 229, 0, 2 | 13:33:22Z |
| `ap8` | the final package (`DFA943D1…`) | `OSFile25` | 13:33:22 to 13:43:00Z | 229, 0, 2 | 13:43:00Z |

The final package is the Release build of `9783d2a` with the help file of
`7bc7925` (the section on the measurement of `7bc7925`). Both runs used the
controller and the live tests of the repository (Git blobs `635bf162…` and
`efe36e50…`), and the log of `ap8` starts with the hash of `NTFSSecurity.dll`.

Per role (the same in each cell, in both editions, and in both runs): Delegate
69, 0, 0; ServerAdmin 36, 0, 0; Admin 51, 0, 1; Server 73, 0, 1 (passed,
failed, skipped). The validation of each cell gave exit code 0, and the
clean-up verdict was `CLEAN`. A read-only check of both labs at 10:46 and
10:47Z (`E\verify-final2`) found no fixture, scheduled task, stage item, probe
account, or profile left in the matrix lab or in the first lab.

**The end state after the last run** (`ap8`, 13:43 to 13:45Z, `E\verify-ap8`).
The same read-only checks, with the SIDs of the last fixtures: the matrix lab
(13:43:43Z) and the first lab (13:44:28Z) are `CLEAN`, with no fixture,
scheduled task, stage item, probe account, profile, or group member left, and
`Verify-Client.ps1` found on `OSWin11` (13:44:43Z) no scheduled task
`NtfsMatrix*`, no stage item, no probe user or profile, no share, and no folder
or user of the fixture. `OSWin11E` shuts itself down an hour after its start
(it was started at 13:15Z).

## The suite on the machines of the matrix lab

The unit suite ran on the three file servers of the matrix lab (Windows Server
2019, 2022, and 2025, domain members) and on its Windows 11 client, as the 22
behavior files that `Run-MatrixLocalSuite.ps1` stages, the four new files among
them, elevated and as a basic user, in both editions. The first run of the
package of this work found a failing test of this work; the section tells how
it was found and fixed, and the full runs after the fixes are at its end. The
first run was `fix1` (21:30 to 22:10Z, 1,152 cases, the pristine package of
`b2cb47b` and its test files; `E\localsuite-final`). The three machines gave
the same counts:

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,132 | 1 | 19 | 1,152 |
| Windows PowerShell 5.1, basic user | 883 | 0 | 269 | 1,152 |
| PowerShell 7, elevated | 1,130 | 1 | 21 | 1,152 |
| PowerShell 7, basic user | 881 | 0 | 271 | 1,152 |

The six basic-user runs passed. The six elevated runs failed the same test, a
new one of this work in `ParameterSets.Inheritance.Tests.ps1`:
`Disable-NTFSAuditInheritance -SecurityDescriptor should take two piped
descriptors and report both in order, written only by Set-NTFSSecurityDescriptor`
fails with `Expected $false, but got $true` at the check that the file on disk
is unchanged by the in-memory change. The host passes it in all four
configurations.

**Cause: the oracle of the test, not the module.** The check read the SACL of
a fresh file with `Get-Acl -Audit`, which reads it together with the other
sections. A diagnostic run of the same file with prints (run `rep1`, elevated,
both editions, on `OSFile25` and `OSFile19`; `E\repro`) shows the reads side
by side for a file without audit entries:

| State of the file | `Get-Acl -Audit` | SACL read alone (.NET) | `Get-NTFSInheritance -Path` |
| --- | --- | --- | --- |
| fresh, and after `Get-NTFSSecurityDescriptor` | protected | not protected | audit inheritance enabled |
| after the piped call of the descriptor, before `Set-NTFSSecurityDescriptor` | protected | not protected | audit inheritance enabled |
| after `Disable-NTFSAuditInheritance -Path` | protected | protected | audit inheritance disabled |

The file on disk was not changed by the in-memory call, as the test intends;
only the oracle read "protected" before and after it.
`Security2\FileSystem\FileSystemSecurity2.cs` and the
[acceptance of the matrix](../Lab/Acceptance-2026-10-10-os-matrix.md) already
describe this difference for Windows Server 2022 and 2025 and Windows 11, and
the module reads the SACL alone for that reason. The diagnostic adds Windows
Server 2019, where the baseline of that acceptance had not been run, and shows
the same in both editions.

**The fix** (`f1f3d8f`): five assertions of two new files read the SACL alone
through .NET (`Get-TestAuditAcl`), as the module does. One of them failed. Four
more expected "protected" for an item that ends without audit entries
(`Set-NTFSInheritance -SecurityDescriptor` after the write, the `Disable` rows
of two piped tests, and `Clear-NTFSAudit -DisableInheritance`); on a domain
member the combined read gives that answer whether or not the flag was
written, so they could not fail there, and they are strengthened too. The
assertions that read the flag of an item with explicit audit entries or compare
an SDDL before and after are unchanged, as are the older files: they read the
flag from an in-memory descriptor or, in the live test, from folders that hold
explicit audit entries.

**Verification of the fix.** The two changed files (78 cases) ran again with
the pristine package on the three file servers, elevated, in both editions (run
`rep2`, `E\repro-fixed`): 76 passed, 0 failed, 2 skipped on each. On the host
(run `hostfix`, `E\repro-host`) they passed in the four configurations:
elevated 76, 0, 2; basic user 40, 0, 38 (passed, failed, skipped). The 35
mutations of Stage C ran on the host before this change; both versions of the
oracle pass on the host, so the mutation table is stated as measured and was
not repeated.

**The full suite after the fixes.** Two full runs followed, each on the three
file servers and on the Windows 11 client (build 28000.1836, reached with its
local installation account):

- `fix2` (22:32 to 23:12Z, `E\localsuite-final2`) and `fix2c` (22:45 to
  22:55Z, `E\localsuite-final2-client`) ran the test files of `f1f3d8f` on the
  package of `b2cb47b`: 1,152 cases in each configuration, and all 16
  configurations passed (1,133, 883, 1,131, and 881 passed; 19, 269, 21, and
  271 skipped, in the order of the table below).
- `fix5` (00:00 to 00:41Z, `E\localsuite-final5`) and `fix5c` (00:02 to
  00:13Z, `E\localsuite-final5-client`) ran the test files of `61e936e` on the
  package of the final build (`8a625c8`; the log of each run starts with the
  hash of `NTFSSecurity.dll`, `6A3F4239…`, and with the hashes of the 23 staged
  files, which equal those of the commit): 1,156 cases in each configuration,
  the 1,152 and the four rows of the filter test. All 16 configurations
  passed, and the four machines gave the same counts:

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,137 | 0 | 19 | 1,156 |
| Windows PowerShell 5.1, basic user | 887 | 0 | 269 | 1,156 |
| PowerShell 7, elevated | 1,135 | 0 | 21 | 1,156 |
| PowerShell 7, basic user | 885 | 0 | 271 | 1,156 |

The four rows of the filter test execute in all four configurations on all four
machines, and the skips are the same on every machine and in `fix2` (19 and 21
elevated, 269 and 271 as a basic user). So the final build passes the 22 files
on Windows Server 2019, 2022, and 2025 and on Windows 11, the operating systems
of the matrix, where the first run found the failure of the oracle. The runner
removes its scheduled tasks and its stage folder on each machine at the end of
a run; an independent check of the end state of the labs followed (the end of
the section Lab acceptance of the fixed build).

**The suite on the final package.** The fix of the piped `AppliesTo` came after
`fix5`. The chain `ap6` ran the 22 files of `93ed2c7` on the three file servers
(`E\localsuite-ap6`; evidence of that commit only: 1,175 cases in each of the
12 configurations, no failure). The chain `ap8` ran the 22 files of `7bc7925`
on the package of the final build: on the three file servers from 12:24 to
13:05Z (`E\localsuite-ap8`) and on the Windows 11 client from 13:05 to 13:15Z
(`E\localsuite-ap8-client`). The log of each run starts with the hash of
`NTFSSecurity.dll` (`DFA943D1…`) and the hashes of the staged files, which
equal those of the commit. Each of the 16 configurations ran 1,189 cases (the
1,175 of `ap6` and the 14 rows that the later commits added) and passed, and
the four machines gave the same counts:

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,170 | 0 | 19 | 1,189 |
| Windows PowerShell 5.1, basic user | 905 | 0 | 284 | 1,189 |
| PowerShell 7, elevated | 1,168 | 0 | 21 | 1,189 |
| PowerShell 7, basic user | 903 | 0 | 286 | 1,189 |

The skips of the elevated runs are those of `fix5` (19 and 21), and the 15
more skips of the basic-user runs are the audit rows that need the Security
privilege (the host has the same 15 more in each of its two basic-user
configurations, 696 skipped rows against 666 at `61e936e`). The commit
`6143545` changed three titles of audit rows after these runs, and removed from
them a comparison of the DACL before and after a call that fails while the
parameters bind; it cannot make a test fail, and the host ran the files of
`2112ee3` (the measurement of `2112ee3`, in the section on the fix), but the
domain members ran the files of `7bc7925`.

## The fix of the piped `AppliesTo`

The maintainer asked on 2026-10-11 why a piped `AppliesTo` is dropped for a
path, was told the cause, and decided to fix it test-first and to accept the
fix in the labs (decision 23). The work is six commits on `21188b1`, in the
order that the evidence tells it: `88ed362` (a test for a Minor finding of the
second review), `93ed2c7` (the fix), `9783d2a` (a defect of that fix, found by
the third independent review), `7bc7925` (the words and tests that the first
check of the correction asked for), `6143545` (three test titles) and
`2112ee3` (the words that the second check asked for); the commits of this
report and of the Memory Bank follow them.

### The change

`Add-NTFSAccess`, `Remove-NTFSAccess`, `Add-NTFSAudit`, and `Remove-NTFSAudit`
declared `DefaultParameterSetName = "PathComplex"`. An object piped with
`Path`, `Account`, and `AccessRights` satisfied the mandatory parameters of
that set, so PowerShell settled on it and never tried `PathSimple`, and the
property `AppliesTo` was dropped. `4b1abc9` had made `-AppliesTo` mandatory in
the Simple sets, so that a `-SecurityDescriptor` call without a scope resolves;
since then the default set decides no named call. `93ed2c7` removes the
argument, one line in each cmdlet. What an object that is piped with a path
does:

| The object has | Before | After |
| --- | --- | --- |
| `AppliesTo` | `PathComplex`; the property is dropped and the entry gets the default scope | `PathSimple`; the entry gets the scope |
| `InheritanceFlags` or `PropagationFlags` | `PathComplex` | `PathComplex` |
| none of them | `PathComplex`, the default scope | `PathComplex`, the default scope |
| `AppliesTo` and `InheritanceFlags` | `PathComplex`; `AppliesTo` is dropped | `AmbiguousParameterSet`, like the same two named parameters |
| `Path` and `SecurityDescriptor` (a hand-built object; no cmdlet of the module produces one) | `PathComplex`: the path wins, and the descriptor is ignored | `AmbiguousParameterSet` |
| an `AppliesTo` that is `$null` (also the missing column of a CSV row that has fewer fields than its header) | ignored | the binding fails for that object ("Cannot bind argument to parameter 'AppliesTo' because it is null"), and the cmdlet goes on with the next |
| an `AppliesTo` that PowerShell cannot convert to a scope (the blank cell that `Import-Csv` reads, a misspelled name) | ignored | ignored, as before: the object is handled as one without `AppliesTo`, so it uses its own `InheritanceFlags` and `PropagationFlags`, and gets the default scope when it has none |

The probe `E\probes\p-proto-appliesto.ps1` (15 calls, run in both editions on
the package of the build before the fix, on a scratch build of the change, and
on the package of `93ed2c7`) shows the differences of the first and fourth rows
of the table, and the sets in the order of the declaration, and nothing else.
The scratch build and the package of `93ed2c7` agree line by
line, and so do the two editions. The last three rows of the table were probed
later, with the package of the fixed build and the build before the fix, both
editions: `E\probes\p-empty-appliesto.ps1` (`empty-appliesto-*.txt`) for the
empty and the invalid values, and `E\probes\p-unconvertible-appliesto.ps1`
(`unconvertible-appliesto-*.txt`) for the empty string and the misspelled name
alone and next to a flag, for `$null`, for a CSV row with fewer fields than its
header, and for an object with `Path` and `SecurityDescriptor`; the fixed build
is the package of `9783d2a` with the help file of `7bc7925`.
Unchanged are the named calls with and
without `-AppliesTo` (the conflict with `-InheritanceFlags` fails as before),
`-SecurityDescriptor` without a scope (the case of `4b1abc9`), a piped
descriptor object with `AppliesTo`, the round trip
`Get-NTFSAccess -Path $source | Add-NTFSAccess -Path $target`, and
`Get-ChildItem | Add-NTFSAccess -Account ... -AccessRights ...`. The rule
objects (`FileSystemAccessRule2`, `FileSystemAuditRule2`), the descriptors, and
the file objects carry no property `AppliesTo`, so the documented pipeline
input binds `PathComplex` as before. `Get-Command` lists the sets in the order
of the declaration, `PathSimple` first, and no default.

A stand-alone model of the binder with no default set predicted this before
the real cmdlets were touched. The first (`E\probes\p-parameterset-binding.ps1`)
has the two Path sets, in four variants of the default set; the second
(`p-parameterset-binding2.ps1`) has the four sets, with and without the
default, and a class of the same shape as the descriptor. Both, in both
editions, give `PathSimple` for an object with `AppliesTo`, `PathComplex` for
one without, an error for one with `AppliesTo` and `InheritanceFlags`, and
named calls as before. The second model binds `PathComplex` for a piped
descriptor object, where the real cmdlets bind `SDSimple`: a model predicts, the
cmdlet decides, so the real cmdlets were probed before the change was kept.

Two consequences are in the changelog entry, as the rows of the table: an
object with `Path` and a `SecurityDescriptor` fails with `AmbiguousParameterSet`
where the path won, and a call with neither `-Path` nor `-SecurityDescriptor`
fails with `AmbiguousParameterSet` instead of a missing-parameter error for
`-Path`.

### The third independent review

The review of `21188b1..93ed2c7` (the built-in `code-review` agent again,
read-only, one pass) found one Major and two Minor findings and no Blocker. It
checked the compatibility of removing the default set: no reader of
`DefaultParameterSet` in `Tests`, `.github`, `Docs`, the wiki export, or the
lab controller; identical results on both builds, in both editions, for the
rule objects of `Get-NTFSAccess` and `Get-NTFSAudit` piped back in (also through
`Export-Csv` and `Import-Csv`), for file objects with a named account, for
`Get-NTFSSecurityDescriptor` output, for positional and named calls, and for a
piped hashtable.

**The Major finding, reproduced in both editions on the package of `93ed2c7`.**
`ProcessRecord` of the four cmdlets wrote the scope that it converts from
`AppliesTo` into the fields behind `-InheritanceFlags` and
`-PropagationFlags`. PowerShell resets only the parameters that the previous
piped object bound, so an object with no scope, or with one flag, took the
scope of the object before it: `AppliesTo ThisFolderOnly`, then none, gave
`None` twice, and the Remove cmdlets left the `InheritOnly` part of every
entry. The change of `93ed2c7` made that reachable for piped path objects. For
piped `-SecurityDescriptor` objects it is a defect of rc7: the probe
`E\probes\p-csv-blank-appliesto.ps1` on the package of the build before the fix
gives `None/None` twice for two descriptor objects with `AppliesTo
ThisFolderOnly` and none. My first tests piped one object per call, so they
could not see a value that stays for the next object; a pipeline test needs two
objects of different shape.

**The fix (`9783d2a`).** The flags of a record are locals, and the fields keep
only what the parameters bound. The loops of `Remove-NTFSAccess` and
`Remove-NTFSAudit` converted the scope a second time into the same fields (the
trivial observation of the first version of this report); the locals make that
redundant, so it is gone. The tests pipe objects of different shape in one
call into each of the four cmdlets, for paths and for descriptors, and the
changelog names the new errors.

The two Minor findings: the `PathSimple` row of the Remove-NTFSAudit pipe test
passes without the fix of `93ed2c7`, because its entry is on a file, where the
scope does not matter (its comment says so now, and the new Contexts on
folders tell the sets apart); and the changelog entry did not name the error
of a call without a path.

**The verification of the fix.** The same reviewer, asked to verify `9783d2a`
(probes of a copy of the package in both editions, identical results), found the
production change correct: no value of one piped record
reaches the next in the four cmdlets (it probed `-AccessType`, records without
a mandatory parameter or without a path, two paths in one record, named calls,
descriptor calls, and `-RemoveSpecific`), the lambdas capture the right locals,
and the rc7 tag has the same carry-over for descriptor objects. It found one
Major and one Minor finding, both about the empty cell. The statement of the
changelog entry and of the four pages that an empty `AppliesTo` fails to bind
holds for `$null` only: an empty string, such as a blank cell that `Import-Csv`
reads from a file, is ignored and the row gets the default scope, and so is a
value that is not the name of a scope (`'NoSuchScope'`: the entry gets the
default scope, which is the broader one; a loud failure for it needs code, a
design change: open item 3). My probes and tests had used `ConvertFrom-Csv` of
strings, which makes a trailing blank cell `$null`, so they had shown the one
route where the statement holds. `7bc7925` corrected the changelog entry, the
four pages, and the help file, and the tests read a file with `Import-Csv`.

**The second check, of `7bc7925` and of this report.** The same reviewer,
asked to verify `7bc7925` and the new sections of this report (probes of copies
of the packages of `93ed2c7` and of the final package, in both editions, with
identical results; the labs and the Memory Bank were outside its scope), found
no Blocker and no Major finding, and seven Minor findings. It confirmed that
the statements about `$null`, an empty string, a space, a misspelled name,
`AmbiguousParameterSet` for a scope together with a flag, and for a call with
neither `-Path` nor `-SecurityDescriptor` are true in both editions; that the
pages and the help file say the same; that the three tests of the CSV route in
each file fail on the build before the fix for the stated reasons and pass on
the fixed build; and the numbers of the measurement of `7bc7925` (1,492 cases,
3,266 of 3,668 points, 696 skipped rows of 174 tests, the inventory and the
classification byte-equal to those of `9783d2a`). The findings:

| # | Finding | Resolution |
| --- | --- | --- |
| 1 | "An empty string or a value that is not the name of a scope is ignored, and the object gets the default scope" is too general. A number converts (`'0'` and `0` give `ThisFolderOnly`; 13, 14, 99, and -1 are ignored), `'ThisFolderOnly,SubfoldersOnly'` binds `SubfoldersOnly`, an array of names and a padded or lower-case name bind. An unusable `AppliesTo` next to a flag gives the flag, not the default scope. A CSV row with fewer fields than its header gives `$null` and fails | The changelog entry, the four pages, and the help file now say that a value that PowerShell cannot convert is ignored, that the object is then handled as one without `AppliesTo` (its own flags, else the default scope), and that a CSV row with fewer fields gives `$null` (`2112ee3`). My probe `p-unconvertible-appliesto.ps1` (both editions, the package of the fix and the package before it) shows the empty string, a misspelling, and 99 ignored; the flag next to an empty string; `$null` and the short CSV row failing; and a lower-case name, a padded name, `0`, `'0'`, and an array of one name binding. The rules for lists and other numbers are those of an enum parameter and are not repeated in the text |
| 2 | "Two consequences are in the changelog entry": the second one, an object with `Path` and a `SecurityDescriptor`, was not | The entry and the four pages name it (`2112ee3`), and the table of the change has a row for it |
| 3 | "The blank-cell test cannot go red through the product code alone" is false | Run on the package of `93ed2c7` (`E\tdd5red93`), the 89 cases fail in 10 places elevated and 5 as a basic user, the two blank-cell tests among them (the tests, red and green) |
| 4 | `7bc7925` is said to correct the decision and this report, but it changed the changelog, the pages, the help file, and two test files; "no agent read it again" is out of date | The text names the commit of each change, and the review of `7bc7925` is this check |
| 5 | Decision 24 says "the Major finding of the second review", which was the third review's; it does not name the second stop of the chain | Decision 24 names the third review and both stops |
| 6 | "The first version of the model was unfaithful (`SecurityDescriptor` was an `[object[]]`)": no saved file shows it | The text says what the two saved models contain |
| 7 | The three audit rows that reject a call with `AppliesTo` and `InheritanceFlags` say that they change nothing, but compare the DACL, which the audit cmdlets never write | The rows say and assert the error only (`6143545`); the access rows compare the DACL, which is what those cmdlets write |

The reviewer could not check the durations of the reviews, which no file of
the evidence records (the report no longer states them), the first build of
`mutA` (the report says that it is not kept), the interactive prompt of a call
without `-Path` (open item 3 says so), and platyPS.

### The tests, red and green

Each run is the focused Pester run of the files in the four configurations
(`E\tdd3`, `E\tdd4`, `E\tdd5`, `E\tdd5red`, `E\tdd5red93`, `E\tdd6`; the logs
`tdd3red2-*`, `tdd3green-*`, `tdd4red2-*`, `tdd4green-*`, `tdd5-*`, `tdd5red-*`,
`tdd5red93-*`, and `tdd6-*`):

| Run | Build | Files and cases | Elevated, Desktop and Core | Basic user, Desktop and Core |
| --- | --- | --- | --- | --- |
| red for `93ed2c7` | the build before the fix | the two ParameterSets files, 75 cases | 62 passed, 12 failed, 1 skipped | 38 passed, 8 failed, 29 skipped |
| green for `93ed2c7` | `93ed2c7` | the two files and the Items file, 209 cases | 208 and 207 passed, 0 failed | 174 and 173 passed, 0 failed |
| red for `9783d2a` | `93ed2c7` | the two files, 87 cases | 78 passed, 8 failed, 1 skipped | 48 passed, 4 failed, 35 skipped |
| green for `9783d2a` | `9783d2a` | the three files, 221 cases | 220 and 219 passed, 0 failed | 180 and 179 passed, 0 failed |
| red for `7bc7925` | the build before the fix (`8a625c8`) | the two files with the `Import-Csv` and `$null` rows, 89 cases | 62 passed, 26 failed, 1 skipped | 38 passed, 15 failed, 36 skipped |
| red for `7bc7925` | `93ed2c7` | the same 89 cases | 78 passed, 10 failed, 1 skipped | 48 passed, 5 failed, 36 skipped |
| green for `7bc7925` | `9783d2a` (the same source) | the same 89 cases | 88 passed, 0 failed, 1 skipped | 53 passed, 0 failed, 36 skipped |
| green for `2112ee3` | `9783d2a` (the package of the lab runs `ap8`) | the two files after `6143545` changed three titles, 89 cases | 88 passed, 0 failed, 1 skipped | 53 passed, 0 failed, 36 skipped |

The 12 failures of the first red run are, for Add-NTFSAccess, the three rows
that pipe `AppliesTo` (the entry gets the default scope) and the row that pipes
`AppliesTo` and `InheritanceFlags` (no error); for Add-NTFSAudit the same four,
one of them the `PathSimple` row of the older test; and for each of the two
Remove cmdlets the row with `AppliesTo` (the entry is removed whole) and the
row with both properties. The 8 failures of the basic runs are the six access
rows and the two audit rows that need no privilege. The 8 failures of the
second red run are exactly the eight tests that pipe objects of different
shape; the CSV rows of that round passed on `93ed2c7`, because each of their
rows has an `AppliesTo` of its own, and no value stays from a row that has
none. Two defects of my own tests showed. Two rows of the first red run failed
for the wrong reason (the variable `$left` of the test body overwrote the row
variable `$Left`, because PowerShell variable names ignore case). The CSV rows
of the second round read strings with `ConvertFrom-Csv`, which makes a
trailing blank cell `$null`, and said that an empty cell fails to bind; the
follow-up review showed that this holds for `$null` only. A blank cell that
`Import-Csv` reads from a file is an empty string, which the binder cannot
convert, so `PathSimple` does not bind and the row gets the default scope. The
tests read a CSV file with `Import-Csv`, the route that the documentation
shows, and pin the blank cell as the default scope and the `$null` object as a
binding error for that object only (`7bc7925`). Run against the build before the
fix, the three tests of that route fail in each of the two files, for the
expected reasons (every row gets the default scope, and the `$null` object
gives no error; `E\tdd5red`). Run against `93ed2c7`, the 89 cases fail in 10
places elevated and in 5 as a basic user (`E\tdd5red93`): the eight tests of
the mixed pipelines and the two blank-cell tests, because the scope of the row
before reaches the blank row. An earlier version of this paragraph said that the
blank-cell test cannot go red through the product code alone; that was a
conclusion without a run, and the run shows the opposite. On `9783d2a`, all
of them pass. The commit `6143545` then changed three titles of audit rows
(the second check, finding 7); the run `tdd6` is the proof that nothing else
changed.

**Mutations of the culture test** (the Minor finding 1 of the first review,
`88ed362`): the test now reads the culture of the thread in the next pipeline
stage for each item, and once after the call. Three mutations of
`GetChildItem2.cs`, each in a scratch worktree (`E\proto-appliesto`) and
restored after the run, fail it: writing the item inside the scope of the
invariant culture (`mutB`: 4 rows fail, 130 passed of 134 in Windows PowerShell
5.1, elevated); leaving the scope without restoring the culture (`mutA2`: 4
rows fail in both editions); and (`mutC`) restoring it only after a `MoveNext`
that returns an item, which only the assertion after the call catches. The
first build of `mutA` did not hold the mutation (a restore of the file ran at
the same time as the edit; a probe of that build, which shows the culture of
the thread empty after the call, was run on the second build), and its run is
not evidence. `mutC` fails the same four rows in both editions, and the
message is the one of the assertion after the call ("because the cmdlet
restores the culture of the caller": `'tr-TR'` expected, `''` found), so each
of the two assertions has a mutation that only it catches (`E\tdd3`, `E\tdd4`).

### The measurement of `9783d2a`

`93ed2c7` was measured first (`E\final6`: 1,478 cases per configuration,
3,262/3,664 sequence points) and was superseded by `9783d2a` before its lab run
was finished, so the numbers below are those of `9783d2a`. It was built once,
in a new frozen worktree (`E\final7build`: Release, 0 errors, 317 warnings, the
same as at `fa0701b`; the package that `New-ModulePackage.ps1` makes and its
extracted copy are hash-equal, `NTFSSecurity.dll` `DFA943D1…`), and measured
with the commands of the earlier measurements (`Chain-Remeasure.ps1`:
Validate, Coverage, and the skip eligibility on a second tree that holds the
same bytes).

- Validate (no instrumentation): 1,490 cases in each of the four
  configurations, no failure (1,459 at `61e936e`; the 31 rows of the
  `AppliesTo` fix):

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,464 | 0 | 26 | 1,490 |
| Windows PowerShell 5.1, basic user | 1,200 | 0 | 290 | 1,490 |
| PowerShell 7, elevated | 1,433 | 0 | 57 | 1,490 |
| PowerShell 7, basic user | 1,169 | 0 | 321 | 1,490 |

- Skip eligibility, by row: 694 skipped rows of 173 distinct tests (666 and 165
  at `61e936e`). Every skipped row executes in at least two other
  configurations, and no skipped row lacks an executed counterpart. The 28 new
  skipped rows are 14 audit rows in each of the two basic-user configurations,
  which need the Security privilege.
- The instrumented runs gave the same counts. The measured assemblies:

| Assembly | SHA-256 |
| --- | --- |
| `NTFSSecurity.dll` | `DFA943D15B9DA0580020625EB4741F635F70E1679D72046660E602470480842A` |
| `Security2.dll` | `9B8AA25ADA31337388E9C2EDAD3D93B42D2EAE6EE7CF0146D85FFDABFB29A33F` |
| `ProcessPrivileges.dll` | `615774328D04633DE27ED78A1971AD3C09C0D9FA922C4DE7CDA3EFB6CA6A4ECC` |
| `PrivilegeControl.dll` | `585F8FFD630A75FDC1041C0AC50AF3FCE0719048A3D7ACE055D6BD44B855D5BF` |

| Assembly | Sequence points | Sequence coverage | Branch points | Branch coverage |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 1,980/2,187 | 90.53% | 679/1,093 | 62.12% |
| Security2 | 1,061/1,240 | 85.56% | 509/753 | 67.60% |
| ProcessPrivileges | 205/219 | 93.61% | 72/125 | 57.60% |
| PrivilegeControl | 20/22 | 90.91% | 12/17 | 70.59% |
| Aggregate | 3,266/3,668 | 89.04% | 1,272/1,988 | 63.98% |

The explicit branch points that a person wrote are 1,086/1,164 (93.30%;
1,090/1,168 at `61e936e`): the two conditions of the second conversion in the
loops of the Remove cmdlets, four points, are gone. The sequence points grew by
four: the two locals of each of the four methods add eight, and the second
conversion removes four. The build visits eight points more than the build of
`61e936e`: the eight of the locals, and the four getters that the new rows
supply (`AddAccess.AppliesTo`, `.InheritanceFlags`, `.PropagationFlags`, and
`RemoveAccess.AppliesTo`), less the four visited points that were removed.
The unvisited inventory has 183 methods, 402 sequence points, and 78 explicit
branch points: the 187 methods of `61e936e` less the four getters. Each is
classified (none unclassified), 167 as explained and 16 as open (the 8 methods
that the paths report left to the maintainer, and 8 getters of pipeline
parameters; `classification-final7.csv`). Two unvisited lambdas of the audit
cmdlets have new compiler-generated names (`<>c__DisplayClass35_1` and
`39_1`).

Compared by position with `61e936e` (`merge\final5-vs-final7-points.csv`),
4,618 points (3,506 sequence points and 1,112 explicit branch points) exist in
both builds. None of them is visited by the run of one build and not by the
other, but the four getters, which only the new run visits. The other 214
positions of each build are in the four changed `ProcessRecord` methods, their
lambdas, and the two `EndProcessing` methods that follow them (their lines
moved), and they cannot be aligned: 196 of them are visited in each build, and
18 are not. The merged tables of the sources (Methods and Cmdlets) are still
those of `b2cb47b`.

### The measurement of `7bc7925`

`7bc7925` changes two test files, the changelog, the four cmdlet pages, and the
help file; the product code is that of `9783d2a`. A Release build is not
byte-reproducible, and a new build would not be the one that the labs accepted,
so none was made: `E\final8build` is the pristine Release folder of
`E\final7build` with the help file of `7bc7925` (`en-US\NTFSSecurity.dll-Help.xml`;
the four assemblies, the manifest, and every other file are hash-equal to those
of `final7build`, and `bytes-note.txt` says so). The chain
`Chain-Remeasure.ps1` refused to run when a file outside the tests and the
documents differs from the commit of the pristine build (none does), copied the
20 files of the pristine folder into a new frozen worktree and a new
eligibility worktree (all hashes equal), and ran Validate, Coverage, and the
skip eligibility (`E\final8`, `E\eligibility-final8`; 12:22 to 12:39Z).

- Validate (no instrumentation): 1,492 cases in each of the four
  configurations, no failure (1,490 at `9783d2a`: each of the two files has one
  more test of the CSV route):

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,466 | 0 | 26 | 1,492 |
| Windows PowerShell 5.1, basic user | 1,201 | 0 | 291 | 1,492 |
| PowerShell 7, elevated | 1,435 | 0 | 57 | 1,492 |
| PowerShell 7, basic user | 1,170 | 0 | 322 | 1,492 |

- Skip eligibility, by row: 696 skipped rows of 174 distinct tests (694 and 173
  at `9783d2a`). Every skipped row executes in at least two other
  configurations, and no skipped row lacks an executed counterpart. The two new
  skipped rows are the new audit test in each of the two basic-user
  configurations, which need the Security privilege.
- The instrumented runs gave the same counts and the same measurement as
  `9783d2a`: 3,266/3,668 sequence points (89.04%), 1,272/1,988 branch points of
  the summary (63.98%), and 1,086/1,164 explicit branch points (93.30%). The 19
  measured files of the two runs have the same names and hashes, so the four
  assemblies are those of the table above. Merged by position with the run of
  `9783d2a` (`merge\final7-vs-final8-points.csv`), both runs have the same 3,668
  sequence points and 1,164 explicit branch points and visit the same ones: the
  second run adds none. The inventory of the unvisited methods (183 methods,
  402 sequence points, 78 explicit branch points) and the classification (167
  explained, 16 open) are byte-equal to those of `9783d2a`.

The unit suite on the machines of the matrix lab and the cells of the matrix lab
ran on this package (the sections on the suite and on the acceptance), and the
first lab ran on the package of `9783d2a`; the two packages differ in the help
file only.

### The measurement of `2112ee3`

`6143545` changes one test file (three titles, and the comparison of the DACL
that they no longer claim), and `2112ee3` the changelog, the four cmdlet pages,
and the help file; the product code is still that of `9783d2a`. As for
`7bc7925`, no build was made: `E\final9build` is the pristine Release folder of
`E\final8build` with the help file of `2112ee3`, and `bytes-note.txt` says that
this file is the only one outside the tests and the documents that differs from
`9783d2a`, and the only one that differs from the package of the lab runs. The
chain ran Validate, Coverage, and the skip eligibility on those bytes
(`E\final9`, `E\eligibility-final9`; 13:24 to 13:41Z). The run also executes the
tests that check the texts of the final commit: the help tests, which compare
what `Get-Help` shows with the pages of `Docs\Cmdlets`, and the tests of the
release notes, which parse `CHANGELOG.md`.

- Validate (no instrumentation): 1,492 cases in each of the four
  configurations, no failure, and the same passed and skipped counts as at
  `7bc7925` (1,466 and 26, 1,201 and 291, 1,435 and 57, 1,170 and 322).
- Skip eligibility, by row: the same 696 skipped rows of 174 tests as at
  `7bc7925` (no row differs), each executed in at least two other
  configurations.
- The instrumented runs: 3,266/3,668 sequence points, 1,272/1,988 branch
  points of the summary, and 1,086/1,164 explicit branch points, as before.
  The 19 measured files have the same names and hashes as those of `7bc7925`,
  the merge by position with that run (`merge\final8-vs-final9-points.csv`)
  adds 0 points, and the inventory (183 unvisited methods) and the
  classification (167 explained, 16 open) are byte-equal.

The commits after `2112ee3` change the report, its tables, the lab README, and
the Memory Bank only.

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
    piped `AppliesTo` property is dropped for a path instead of selecting the
    Simple set.
12. **Stage C stopped** at 79 `It` blocks, the target of 15 to 20 per file;
    every remaining gap is in the ParameterSets table. The 12 getters were not
    tested, to keep the measured commit stable for the lab acceptance.
13. **Server Core, ARM64, and a localized system** were not tested (Stage D):
    no new machine without the maintainer's word, and no such image exists.
    Decision 22 drops them.
14. **No kit script.** The commands of the method are in this report, and the
    scripts of the session are named in the evidence; the handoff calls a kit
    welcome, not required.
15. **The suite of the matrix lab** runs the four new files from now on
    (`b2cb47b`), so that the next acceptance proves them on every machine.
16. **A rehearsal** of the final run on `ef45b38` (three of the four files)
    was stopped in the mode Coverage after Build and Validate had passed (1,407
    cases in each configuration), and replaced by the final run.
17. **The audit protection flag is read from the SACL alone in the new tests**
    (`f1f3d8f`, section "The suite on the machines of the matrix lab"). The
    oracle was wrong on a domain member and the module already reads the SACL
    alone, so the test changes and the module does not. The change follows the
    measured commit; the final measurement was repeated on it.
18. **The second culture defect is fixed, and the first fix was incomplete.**
    The review found `Get-ChildItem2 -Filter` in `tr-TR` (the class of
    Decision 8), so the rule of the handoff applies: a failing test, the fix,
    and the acceptance of the fixed build. `0028ccd` fixed the comparison of the
    cmdlet; the probes showed that AlphaFS 2.2 also matches the filter with the
    culture of the thread, so `fbe0289` runs the enumeration with the invariant
    culture. The thread culture changes only around the creation of the
    enumerator and each `MoveNext`, never across a `WriteObject`. The alternative
    without the switch, enumerating everything with `*` and matching only in the
    cmdlet, changes the dot rules of `-Filter` (an open decision of the paths
    report) and the cost of a filtered listing of a share, so it was not taken.
19. **The final measurement and the acceptance are repeated on the build of
    `8a625c8`,** because the product code changed after the build that the first
    acceptance used. The builds of `b2cb47b` (and of `f1f3d8f`, the same bytes)
    and of `0028ccd` (accepted in the first lab, run `fix3`, and not final) stay
    as evidence. The merged tables of the sources (Methods and Cmdlets) are those
    of `b2cb47b`: the other sources must run the same code, and `GetChildItem2`
    changed since, so its final row is measured on its own.
20. **Three independent reviews and two checks, on request.** The first review
    (the built-in `code-review` agent, read-only) found four Major findings and
    several Minor ones. The maintainer then asked for `review: on`, and each
    finished delta was read again: the second review found five Minor
    findings; the third (of the fix of the piped `AppliesTo`) one Major and two
    Minor; its first check of the correction one more Major and one Minor; and
    its second check, of `7bc7925` and of this report, seven Minor findings and
    no Major (section Review). Runs verified every fix. The second review also
    read the fixes of the first, and the checks read the fix of the third. The
    commits `6143545` and `2112ee3`, the three test titles and the words that
    the second check asked for, were not read again.
21. **The cells of the matrix lab ran on the final builds.** For the build of
    `8a625c8` they were first not run, because the change after the acceptance
    that the matrix gave to rc7 is one class, `GetChildItem2`, which the live
    suite of the first lab exercises and the unit suite ran on the three file
    servers and the client. The maintainer asked for them, and they ran on the
    package of `8a625c8` (`mxf`, 2026-10-11 07:33 to 07:57Z; the section Lab
    acceptance of the fixed build). They ran again on the final package, the
    Release build of `9783d2a` with the help file of `7bc7925` (`ap8`, 13:19 to
    13:43Z), after the fix of the piped `AppliesTo`.
    The evaluation client shuts down an hour after each start, so it starts
    right before the cells.
22. **Server Core, ARM64, a localized operating system, and non-Windows file
    servers are out of scope** (the maintainer, 2026-10-11: the audience of the
    tool does not need them; Memory Bank Decision 25). They are not open items
    and no further plan, deployment, or test covers them. The decision is about
    the tests and the acceptance of this work; the question of #34 (Decision 23
    of the Memory Bank) is not changed by it.
23. **The piped `AppliesTo` is fixed by removing the default parameter set**
    (the maintainer, 2026-10-11, after the question why a piped property is
    dropped; Memory Bank Decision 26). The options were to leave it as a
    documented limit; to remove the default set (four attributes; new errors
    for an object with `AppliesTo` and a flag, for an object with `Path` and
    `SecurityDescriptor`, for a `$null` `AppliesTo`, and for a call with
    neither `-Path` nor `-SecurityDescriptor`, see the section on the fix); or
    to keep the default and make `AppliesTo` an optional parameter of the
    Complex sets, which changes the public syntax. The dropped property was a
    silent change of the scope (`ThisFolderOnly` became
    `ThisFolderSubfoldersAndFiles`), and the second option changes the
    declaration only and keeps every named call, so it was taken.
24. **Two lab chains were stopped when a finding arrived.** The chain of
    `93ed2c7` (`ap6`) was stopped when the Major finding of the third review
    arrived. The suite stage that was running on the file servers was left to
    finish, because stopping it would have skipped the clean-up of its runner;
    its results (`localsuite-ap6`: 12 configurations, 1,175 cases each, no
    failure) are evidence of `93ed2c7`, not of the final build. The first
    stage of that chain, the acceptance of the first lab, had failed at once
    (11:21:53Z): `Run-AcceptStage.ps1` has `$PSScriptRoot` in a parameter
    default, which is empty in Windows PowerShell 5.1 with `-File`, and the
    chain judges nothing and went on. A second chain (`ap6b`), meant to repeat
    the acceptance alone, never started a stage; its log has the start line
    only. The chain of `9783d2a` (`ap7`), queued behind that suite stage, was
    stopped at 12:15:58Z, when the first check of the correction found the
    false sentence about empty values, while its first stage, the acceptance
    of the first lab, was running; that stage ran on and ended with exit code
    0 at 12:24:39Z (`accept-ap7.log`). The stages after it ran in the chain
    `ap8`, on the package of `7bc7925` (`final8build`), which names the script
    explicitly.

## Open items for the maintainer

New items of this work; the open items of the paths report (the `FileSecurity`
conversions, the `RemoveAll` filters, the lazy path overloads, the abandoned
`PrivilegeEnabler`, the dot rules of `Get-ChildItem2 -Filter`, the 17
owner-restore handlers, the unused classes, the swallowed initialization errors
of the effective-access check, Decisions 22 and 24, and #34) stay as they are.

1. **Hard-link names under a root that is not the volume root.** A defect with
   a reproduction (Stage C). Options: the names under the real volume root
   (a final path of a handle), the names under the root that the caller gave,
   or a documented limit. The commands in Stage C are the regression test.
2. **`AUDIT-OWNER-RETRY` and `AUDIT-READ-DENIED`** (47 plus 6 sequence points)
   have no trigger on a Windows file server. Closing them needs an answer of a
   file server that is not a Windows server (#34), or a seam that injects the
   exception (a design change).
3. **A piped property `AppliesTo`** was dropped for a path, without a message.
   It is fixed (decision 23, the section on the fix): the four cmdlets declare
   no default parameter set, and the flags of a record are locals. What stays
   for the maintainer is to read the consequences that the changelog entry
   names. An object that has `AppliesTo` together with `InheritanceFlags` or
   `PropagationFlags` fails with `AmbiguousParameterSet`, and so does an object
   that has both `Path` and `SecurityDescriptor`. An `AppliesTo` that is
   `$null` fails to bind for that object, and a CSV row with fewer fields than
   its header has `$null` there. A call with neither `-Path` nor
   `-SecurityDescriptor` fails with `AmbiguousParameterSet` instead of a
   missing-parameter error for `-Path`, so an interactive host no longer
   prompts for the path (the prompt was not exercised). One limit remains, and
   it is silent: a value that PowerShell cannot convert to a scope, such as the
   empty cell that `Import-Csv` reads or a misspelled name
   (`ThisFolderOnlyy`), is ignored, and the object is handled as one without
   `AppliesTo`: it uses its own flags, and gets the default scope, the broader
   one, when it has none. The binder swallows a value that it cannot convert
   to the enum, and a cmdlet does not see the object that is piped, so
   failing loudly needs a design change: `AppliesTo` as an optional parameter
   of the Complex sets too (a change of the syntax), or a string that the
   cmdlet parses itself.
4. **Eight getters of pipeline parameters** that take pipeline input by
   property name and that no test supplies on a piped object
   (`AddAccess.AccessType`, `AddAudit.AuditFlags`, `CopyItem2.Destination`,
   `GetEffectiveAccess.Account`, `GetFileHash2.Algorithm`,
   `MoveItem2.Destination`, `RemoveAudit.AuditFlags`, `SetOwner.Account`):
   tests close them. The rows of the `AppliesTo` fix visit four of the twelve
   that Stage C counted (`AddAccess.AppliesTo`, `.InheritanceFlags`,
   `.PropagationFlags`, and `RemoveAccess.AppliesTo`).
5. **The remaining gaps of 52 sets** in the ParameterSets table (62 `budget`,
   16 `Limit`, 2 `would-pin`, and 3 `MaintainerDecision` mentions), and the four
   `MaintainerDecision` sets with the open item 1 of the paths report. The
   `-SecurityDescriptor` sets other than three were not tested with a direct
   call that passes several descriptors.
6. **A new candidate.** The fixes `419cfb3`, `0028ccd`, `fbe0289`, `8a625c8`,
   `93ed2c7`, and `9783d2a` and the tests are changes after the tag; a new
   candidate, if he takes them, needs the acceptance (matrix cells and first
   lab) on its own bytes. The acceptance of the final package (the first lab on
   the build of `9783d2a`; the suites and the cells on that build with the help
   file of `7bc7925`; the sections on the acceptance and on the fix) is evidence
   for the behavior, not for a release.

## Completion matrix

| Unknown | Status | Evidence |
| --- | --- | --- |
| Coverage of the shipped code (rc7, `fa0701b`) | Closed | Stage A: 3,198/3,649 sequence points (87.64%), 1,090/1,168 explicit branch points; 232 methods classified, none unclassified; the Methods, Cmdlets, and Reconciliation tables |
| Coverage of the live tests | Closed | Stage B: first lab and three matrix cells, 245 and 229 passed per edition, the counts of the uninstrumented acceptance; 1,861 sequence points each, 9 sequence and 4 explicit branch points more than the host unit suite; the cells add nothing to the first lab |
| The unit suite on a domain member | Closed | `OSFile25`, four configurations, the counts of the rc7 acceptance; 9 sequence and 3 explicit branch points more than the host |
| The unit suite of the final build on the other operating systems | Closed | the 22 behavior files on Windows Server 2019, 2022, 2025 and Windows 11 (build 28000), elevated and as a basic user, both editions: 1,156 cases in each of the 16 configurations at `61e936e`, no failure (`fix5`, `fix5c`), and 1,189 cases in each at `7bc7925` on the final package, no failure (`ap8`); the first run (`fix1`) found one failing test, caused by its oracle and fixed in the test (`f1f3d8f`); both labs verified clean afterwards |
| The code of `fdd7a8b` | Closed, with one branch visited by nothing | the ServerAdmin tests (lines 478 and 486) and the basic-user runs on the domain member visit the fall back; the answer "RPC server unavailable" of the context initialization is visited by nothing (explained) |
| `AUDIT-OWNER-RETRY`, `AUDIT-READ-DENIED` | Open, explained | no test visits them; no trigger on a Windows file server (probe of 48 calls); closing needs a non-Windows server (out of scope, decision 22) or a seam (a design change) |
| The reachable gaps, the judged matrix of the 64 parameter sets | Partly closed | 79 `It` blocks (140 rows) and, for the piped `AppliesTo`, 22 more (33 rows); 33 of 35 mutations caught; 7 sets closed, 51 partly, 1 open, 4 `MaintainerDecision`, 1 `None` (the statuses are those of Stage C; the tests of the fix were not judged again); 8 getters of pipeline parameters open; one defect (hard-link names) for the maintainer |
| Other cultures | Closed for `de-DE` and `tr-TR`, after two defects | two defects found and fixed test-first: the comparison of an identity with a name (`419cfb3`) and `Get-ChildItem2 -Filter` (`0028ccd`, `fbe0289`, `8a625c8`), the second found by the independent review after the scan had missed its class of call; six `de-DE` failures are assertions on English text; localized names and texts are out of scope (decision 22) |
| Windows Server Core, ARM64, a localized system, non-Windows file servers | Out of scope | the maintainer's decision of 2026-10-11: the audience of the tool does not need them (decision 22) |
| The final commit | Closed | `2112ee3`, with the product code of `9783d2a`, built once (`NTFSSecurity.dll` `DFA943D1…`) and measured on those bytes (the help file of the commit in the package): 1,492 cases per configuration, no failure; 3,266/3,668 sequence points (89.04%), 1,086/1,164 explicit branch points; skip eligibility by row (696 skipped rows, none without an executed counterpart); 183 unvisited methods, all classified; the merged tables of the sources are those of `b2cb47b` (Final measurement; the section on the fix). At the earlier `61e936e` (built at `8a625c8`): 1,459 cases, 3,258/3,664 points, 187 methods |
| The lab acceptance of the fixed build | Closed, on the final package | the first lab: four runs on four builds (`b2cb47b`, `0028ccd`, `8a625c8`, and `9783d2a`), both editions, 245 passed, 0 failed, 1 skipped each, clean end state; the three cells of the matrix lab on `8a625c8` (`mxf`) and on the final package (`ap8`), 229 passed, 0 failed, 2 skipped per edition each time, clean end states; the unit suite on the final package in 16 configurations (`ap8`). A new candidate needs its own acceptance (open item 6) |

## Review

The handoff asks for one independent review. The maintainer asked for
`review: on` after it, so each finished delta was read again: three reviews and
two checks of the third reviewer, all by the built-in `code-review` agent (the
custom `security-reviewer` cannot start), read-only, and none by the agent that
wrote the code.

| Review | Read | Result |
| --- | --- | --- |
| first | `6696f68..bea855e`, one pass: the production fix, the new tests, the numbers of this report, the Memory Bank, and the change of the matrix runner | 4 Major, several Minor, no Blocker |
| second | `bea855e..21188b1`: the second culture defect, the test changes, the final measurement, the acceptance, and the decision on the environments | no Blocker, no Major, 5 Minor, all in tests and documents |
| third | `21188b1..93ed2c7`, one pass: the fix of the piped `AppliesTo` | 1 Major, 2 Minor, no Blocker |
| first check | the commit `9783d2a`, by the reviewer of the third review, asked to verify the correction of its finding | 1 Major, 1 Minor |
| second check | the commit `7bc7925`, the corrected sections of this report, and the probes of the packages, by the same reviewer | no Blocker, no Major, 7 Minor |

**The findings of the first review**, each resolved or answered with evidence:

| # | Severity | Finding | Resolution |
| --- | --- | --- | --- |
| 1 | Major | The `-eq` example of the changelog entry and of this report is not shown by any evidence and likely does not fail | Probed on the previous build under `tr-TR`: `-eq`, `-contains`, and `-in` return True; only `Equals` failed. The entry and the text now name `Equals` (`0028ccd`) |
| 2 | Major | The culture scan missed the case-insensitive `WildcardPattern` of `Get-ChildItem2`, so "Other cultures: Closed" overclaimed | Reproduced in both editions; fixed test-first (`0028ccd`, `fbe0289`, `8a625c8`; the first fix was incomplete, see Stage D); second scan found no other; acceptance repeated |
| 3 | Major | The test of `Get-Privileges` compares the localized State text of `whoami /priv` | The state is compared only where `whoami` prints the English words (`61e936e`) |
| 4 | Major | The finding on a piped `AppliesTo` contradicts the coverage data of the audit cmdlets | Traced with probes in both editions: a path drops the property for access and audit alike, a descriptor binds it. The audit rows named `PathSimple` bound `PathComplex`; they name `-AppliesTo` now and assert the scope (`61e936e`); text and open item corrected |
| 5 | Minor | Two Items rows "array with an empty element" passed a plain empty string | They pass an array (`61e936e`) |
| 6 | Minor | The empty-path rows of Copy-Item2 and Move-Item2 run with the sandbox as current location | They run in an empty folder of their own (`61e936e`) |
| 7 | Minor | The on-disk proof that an audit entry was written is only that the SDDL differs | The entry is asserted in the descriptor and on disk (`61e936e`) |
| 8 | Minor | Numbers and wording: 67.59% (it is 67.60%); the counts of the 52 sets (they are of the 57 not closed); "each of them asserts the error ID" (only the filter test does); the Runs table (it lacked the final runs); a sentence that no cmdlet reaches an unexplained point (65 methods have no explanation) | All corrected here; the Runs table lists every run |
| 9 | Minor | `b2cb47b` is still called the final commit, and the Memory Bank has the same wording and one overstatement | Updated with the final measurement |

The first reviewer checked and found clean: the production fix of the identity
comparison (null and empty arguments, `GetHashCode`, the operators, the red and
green logs, the restoration of the thread culture, the changelog group);
PSScriptAnalyzer on the new files; the Pester 5 pitfalls (the use of
`BeforeDiscovery` variables, `Set-ItResult -Skipped` with `return`); the
restoration of `EnablePrivileges`, the balance of `Push-Location`, and the
confinement of every destructive call to the sandbox; the remaining reads of the
SACL with `Get-Acl -Audit` (they hold audit entries); about 40 numbers of this
report against the tables; the change of `Run-MatrixLocalSuite.ps1`; and the
agreement of the Memory Bank with the report.

**The findings of the second review**, all Minor, each resolved:

| # | Finding | Resolution |
| --- | --- | --- |
| 1 | The `tr-TR` test of `Get-ChildItem2 -Filter` never asserts that the thread culture is restored after the call or in a later pipeline stage; its own `finally` resets the culture | The test reads the culture in the next stage for each item and once after the call (`88ed362`); three mutations of the restore fail it (the section on the fix) |
| 2 | The Memory Bank lists `string.Equals` without a comparer as culture-sensitive; it is ordinal, and the defect was `ToLower()` | The list names `ToLower`, `ToUpper`, `Compare`, and `StartsWith`, `EndsWith`, and `IndexOf` without a `StringComparison` |
| 3 | The hard-link repro of this report maps `Z:` without a check that the letter is free, and removes the mapping at the end, which would delete a mapping of the user | The repro takes a free drive letter and cleans up in a `finally` |
| 4 | "Nothing was pushed" was stale: the remote branch had been updated by a push 15 minutes before the last commit | The text says that the maintainer pushed the branch (`2b97422`, 2026-10-11), in this report and in the Memory Bank |
| 5 | The mechanism that the report gave for the audit test of a piped descriptor ("because the default set does not compete") contradicts the stand-alone model of the binder | The text says what was measured, that the model is not faithful for a piped descriptor (it binds `PathComplex` where the real cmdlets bind `SDSimple`), and that the real cmdlets are the reference |

The second reviewer checked and found clean: that exactly two production files
differ from rc7 (`GetChildItem2.cs` and `IdentityReference2.cs`) and that
nothing but tests, documents, and the changelog differs between `8a625c8` and
the head of that review; that the culture of the thread is restored on every
path and that nothing writes to the pipeline inside the scope; the cost of the
scope (0.1 to 0.3 µs per item, measured on .NET 10; Windows PowerShell 5.1 not
measured); that no other call in the four projects is culture-sensitive;
PSScriptAnalyzer on the three test files; the Pester 5 phases; every number of
the final measurement recomputed from the OpenCover XML; the Runs CSV (all 120
rows), the Evidence CSV (all 1,168 rows), and the references of the
ParameterSets CSV against their sources; and a scan of the added lines and of
the evidence for secrets and unsafe commands.

**The findings of the third review and of the first check:**

| # | Severity | Finding | Resolution |
| --- | --- | --- | --- |
| 1 | Major | `ProcessRecord` of the four cmdlets wrote the scope of a piped object into the fields behind `-InheritanceFlags` and `-PropagationFlags`, so the next object without a scope took it (rc7 has the same for piped descriptor objects) | The flags of a record are locals (`9783d2a`); eight pipeline tests with objects of different shape, red on `93ed2c7`, green after |
| 2 | Minor | The `PathSimple` row of the Remove-NTFSAudit pipe test passes without the fix, because its entry is on a file | The comment says so, and the new Contexts on folders tell the sets apart (`9783d2a`) |
| 3 | Minor | The changelog entry did not name the error of a call without a path | Named (`9783d2a`) |
| 4 | Major (check) | "An empty `AppliesTo` fails to bind" holds for `$null` only: an empty string, or a value that is not the name of a scope, is ignored and the object gets the default scope | The changelog entry, the four cmdlet pages, the help file, and the tests say so (`7bc7925`); the second check refined the statement (finding 1 below) |
| 5 | Minor (check) | The tests read the CSV rows with `ConvertFrom-Csv`, which makes a trailing blank cell `$null`: the one route where the statement holds | The tests read a file with `Import-Csv` and pin the blank cell (the default scope) and the `$null` object (a binding error for that object) (`7bc7925`) |

The third reviewer checked and found clean: the compatibility of removing the
default set (no reader of `DefaultParameterSet` in the tests, the workflows, the
documents, the wiki export, or the lab controller; identical results on both
builds for the rule objects of `Get-NTFSAccess` and `Get-NTFSAudit` piped back
in, also through `Export-Csv` and `Import-Csv`, for file objects with a named
account, for descriptors, for positional and named calls, and for a piped
hashtable); and, in the first check, the correction itself (no value of one
piped record reaches the next in the four cmdlets, and the lambdas capture the
right locals).

**The findings of the second check** (no Blocker, no Major; the table with the
resolutions is in the section on the fix, under the third review) were seven
Minor findings: the statement about an unconvertible value was too general; the
changelog entry lacked one of its two consequences; a sentence of this report
about the blank-cell test had no run behind it and was false; the text
credited `7bc7925` with edits of later commits; Decision 24 named the wrong
review and one stop too few; the text described a first model that no file
shows; and three audit rows claimed more than they assert. Each was resolved in
`6143545`, `2112ee3`, and the commits of this report.

The last commits, `6143545` and `2112ee3`, carry the test titles and the words
that the second check asked for. No agent read them again: the runs verified
them (the probes, the focused tests in four configurations, and the
measurement of `2112ee3`). The first two reviews saw the code before the fix
of the piped `AppliesTo`; the third and the checks saw the fix.

## Checks not run, and limits

- A coverage percentage counts visited points, not assertions: the mutation
  proofs (35) test the new tests, and the 7 closed sets of the matrix are the
  ones whose named gaps are asserted. The coverage of the unit suite barely
  moved (+45 points, all getters), because the gaps were assertions and not
  lines.
- The 35 mutations ran before the later test changes (`f1f3d8f`, the oracle of
  five assertions, and `61e936e`, the rows of the review) and were not
  repeated. On the host the old and the new oracle pass; whether each mutation
  that one of the changed assertions caught is still caught was not measured.
- The live coverage ran on one first lab and three cells of the matrix lab
  with one client (`OSWin11E`); the matrix cells added no point, so the claim
  that the operating system does not change the code that the tests run
  rests on those three server versions and one client.
- The unit suite ran on a domain member in the 18 behavior files that
  `Run-MatrixLocalSuite.ps1` stages (1,011 of 1,314 cases), not in the files
  that check the repository, the manifest, the help, the wiki, and the release
  scripts, which need the repository.
- The culture scan covers the C# of the four projects and the filter that
  `Get-ChildItem2` passes to AlphaFS; the rest of AlphaFS, a third-party
  library, was not scanned.
- Not run: a hard link through a volume mounted into a folder or through a
  junction to another volume (the defect is reproduced with a substituted
  drive only); the 8 getters of pipeline parameters that no test supplies on a
  piped object; the interactive prompt of a call without `-Path` (the error of
  the non-interactive call is tested); the matrix suite on `OSWin11E` with the
  new files (`OSWin11` ran it); tests of the values of a piped `AppliesTo`
  other than a valid name, a blank cell, and `$null` (probed in both editions,
  `empty-appliesto-*` and `unconvertible-appliesto-*`); an acceptance of the
  first lab on the package with the help file of `7bc7925` (it ran on the
  package of `9783d2a`; the suites and the cells ran on the package with the
  help file of `7bc7925`; the packages differ in the help file only); and any
  lab run on the help file of `2112ee3` (the host ran the help tests on it).
- The domain members and the Windows 11 client ran the test files of `7bc7925`.
  The later changes of the tests (`6143545`: three titles of audit rows, and
  the comparison of the DACL that they no longer claim) ran on the host only.
- Out of scope, and not run, by decision 22: Windows Server Core, ARM64, a
  localized operating system, and a file server that is not a Windows server.
- The Release build is not byte-reproducible: a hash identifies the measured
  files, not the source. Different code has different denominators; the
  measurements of `5a5d58b`, `fa0701b`, and `b2cb47b` are not increments of
  one source, and the comparison is by method and position.
- The custom `security-reviewer` cannot start (its model is unavailable), and
  no model setting was overridden; the independent review (section Review) is
  the read-only built-in `code-review` agent.
- The agent pushed, merged, tagged, and published nothing; the maintainer
  pushed the branch himself (`2b97422` on 2026-10-11), and later commits stay
  local until he pushes them. The stable 5.0.0 stays gated by the other gates,
  and a percentage never closes a gate.

## Evidence outside git

The raw evidence is in the session folder
`C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns`
(`E` above). [The Evidence CSV](Quality-Gate-Unknowns-2026-10-10-Evidence.csv)
lists the files that this report relies on, with size and SHA-256: the copies
of `.dll` and `.pdb` files outside the packages, the frozen worktrees, and the
folders of runs that fed no number are not in it. The folders are:

| Folder | Content |
| --- | --- |
| `fa0701b`, `eligibility-fa0701b`, `inventory-fa0701b`, `classification-fa0701b.csv`, `reconciliation-fa0701b.csv` | Stage A: the frozen worktree, the reports and logs of the four configurations, the pristine and saved assemblies with hashes, the skip rows, and the inventory |
| `live-inst2`, `live-fl1b`, `live-fl2`, `localsuite-osfile25`, `live-matrix`, `probe-auditdenied` | Stage B: the instrumented module and its zero-hit report, the rejected first design, the first lab, the unit suite on the domain member, the matrix cells, and the audit probe, each with the report, the snapshots per process, the validation, and the logs |
| `paramsets`, `impl` | Stage C: the scan, the judged tables and notes, the status tables, and the run logs of the implementers |
| `cultures`, `probes`, `tdd`, `tdd2` | Stage D and the two culture defects: the four culture runs, the probes (`hardlink-root` has the reproduction, `alphafs-*` the enumeration of AlphaFS, `review-*`, `eq-mechanism-*`, and `remove-audit-appliesto-*` the findings of the first review; `p-parameterset-binding*`, `p-proto-appliesto*`, `proto-appliesto-*`, and `csv-blank-*` the model of the binder, the real cmdlets with and without the default set, and the mixed pipelines of the third review; `empty-appliesto-*` the empty and the invalid values of the first check, and `unconvertible-appliesto-*` the values, the CSV row with fewer fields, and the object with `Path` and `SecurityDescriptor` of the second check), and the red and green runs of the identity comparison (`tdd`) and of the filter (`tdd2`) |
| `final`, `eligibility-final`, `inventory-final`, `classification-final.csv` | the measurement of `b2cb47b` and its package |
| `final2`, `eligibility-final2`, `inventory-final2`, `chain-final2.log`, `merge\final-vs-final2-*` | the measurement of `f1f3d8f` on the same bytes, and its comparison with the first by position |
| `final3`, `live-fix3` | the build of `0028ccd` (the first, incomplete fix of the filter) and its acceptance in the first lab |
| `final4`, `final5`, `eligibility-final5`, `inventory-final5`, `classification-final5.csv`, `chain-final5.log`, `merge\final2-vs-final5-*` | the final build of `8a625c8` with its package, the final measurement of `61e936e` on its bytes (`inventory-*\branch-summary-decomposition.txt` holds the split of the branch summary, for rc7 and for the final build), and the comparison with the measurement of `f1f3d8f` by position |
| `live-fix1`, `localsuite-final`, `chain-fix.log` | the lab acceptance of the build of `b2cb47b` and the first run of the unit suite on the file servers |
| `live-fix4`, `localsuite-final5`, `localsuite-final5-client`, `verify-pre`, `verify-final` | the lab acceptance of the final build, the unit suite of the final build on the file servers (`fix5`) and on the Windows 11 client (`fix5c`), and the read-only checks of both labs before the work and after the last run |
| `repro`, `repro-fixed`, `repro-host`, `repro-root`, `localsuite-final2`, `localsuite-final2-client` | the diagnosis of the failing oracle (`rep1`), the runs after the fix on the file servers (`rep2`) and the host (`hostfix`), the test roots of the diagnosis, and the full unit suite at `f1f3d8f` on the file servers (`fix2`) and the client (`fix2c`) |
| `merge`, `scripts` | the merged points by position, and every script of the method |
| `live-matrix-final`, `verify-final2` | the cells of the matrix lab on the package of `8a625c8` (`mxf`) and the read-only check of both labs after them |
| `final6build`, `final6`, `eligibility-final6`, `inventory-final6`, `classification-final6.csv`, `chain-final6.log`, `merge\final5-vs-final6-*`, `tdd3` | the intermediate commit `93ed2c7`, the fix with the defect: its package, its measurement, the red and green runs of its tests, and the mutations of the culture test |
| `chain-reaccept-ap6.log`, `chain-reaccept-ap6b.log`, `stage-accept-ap6`, `stage-suite-ap6`, `localsuite-ap6` | the stopped chain of the lab run of `93ed2c7` (`ap6b` has the start line only) and the suite stage that ran on |
| `final7build`, `final7`, `eligibility-final7`, `inventory-final7`, `classification-final7.csv`, `chain-final7.log`, `merge\final5-vs-final7-*`, `tdd4` | the build `9783d2a`: its package, its measurement, and the red and green runs of its tests |
| `chain-reaccept-ap7.log`, `accept-ap7.log`, `stage-accept-ap7`, `live-ap7` | the first lab on the package of `9783d2a` (the chain driver was stopped after that stage began) |
| `final8build`, `final8`, `eligibility-final8`, `inventory-final8`, `classification-final8.csv`, `chain-final8.log`, `merge\final7-vs-final8-*`, `tdd5`, `tdd5red`, `tdd5red93` | the final package (`9783d2a` with the help file of `7bc7925`, `bytes-note.txt`), the measurement of `7bc7925` on it, and the runs of the tests of the CSV route on the build before the fix, on `93ed2c7`, and on `9783d2a` |
| `chain-reaccept-ap8.log`, `stage-suite-ap8`, `stage-suitec-ap8`, `stage-matrix-ap8`, `stage-verify-labs-ap8`, `stage-verify-client-ap8`, `localsuite-ap8`, `localsuite-ap8-client`, `live-matrix-ap8`, `verify-ap8` | the lab acceptance of the final package after the first lab: the unit suite on the file servers and the client, the cells, and the read-only checks of both labs and of the client |
| `final9build`, `final9`, `eligibility-final9`, `inventory-final9`, `classification-final9.csv`, `chain-final9.log`, `merge\final8-vs-final9-*`, `tdd6` | the measurement of `2112ee3` on the final package with its help file (`bytes-note.txt`), and the focused run of the two ParameterSets files after the change of three titles |

Nothing in the evidence holds a password; the controller keeps them in memory.
