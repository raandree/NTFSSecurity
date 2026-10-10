# Quality-gate path review, 2026-10-09

Handoff 1 of the quality gate before 5.0.0. The C# code that no test visited
at `3442194` was inventoried again. Each path is now covered by a behavior
test or explained from source, and the evidence of every explanation is
named. The work is on `ai/quality-gate-paths`, from the reviewed head
`f11ff41` of `ai/quality-gate-coverage` (#117). Nothing was pushed, merged,
tagged, or published; the stable version stays 4.2.6 and rc6 is the latest
published candidate. Cmdlet design and the fate of unused classes stay with
the maintainer (Decisions 16, 21, and 22; Decision 22 is still proposed).

This report does not close the quality gate. A coverage percentage never
closes it, the [open items](#open-items-for-the-maintainer) remain, and the
fixes below still need the lab acceptance of gate 3.

## Candidate and source identity

- Measured source: `5a5d58b` (`5a5d58b88c639ca560bc1e66b17d57cc6e682eca`).
  Two commits follow it and change no test and no executable code: the
  first rewords a code comment in `NTFSSecurity\BaseCmdlets.cs` and one
  sentence of the `Get-ChildItem2` page with its generated help, as the last
  review passes asked; the second adds this report, its tables (with the
  red/green rows), the appendix, and the Memory Bank notes.
- Base `f11ff41`. Since then 26 commits up to the measured source (8 `fix`,
  1 `refactor`, 16 `test`, 1 `docs`): 40 files, 3,708 insertions and 80
  deletions. Production code is 18 files with 277 insertions and 52
  deletions (the four projects, without the generated help); the rest is
  tests, documentation, and help.
- Build: Release, .NET Framework 4.5.2, 0 errors and 317 warnings: 296 of
  CS1591, 19 of CS1574, one of CS0169, and one of CS0618. All are legacy and
  none was suppressed.
- Tools: Windows PowerShell 5.1.26100, PowerShell 7.6.6, Pester 5.7.1,
  AltCover 9.0.145 (net472).
- The measured assemblies are the Release files that the Validate run used.
  AltCover saved them unchanged before it instrumented them:

| Assembly | SHA-256 |
| --- | --- |
| `NTFSSecurity.dll` | `155DE103C14A7CC69BA179D0AE4EEFA81DCF6F43A34B1856BC01393DDB76D443` |
| `Security2.dll` | `F6E4B6340F55A070B8E7D7678B7A6289E1A8430D393618EC269A315D70F32FC7` |
| `ProcessPrivileges.dll` | `7D037B32AED6C5879993C431F3EB614D61A621C8AF3474B59A6E0A5C451E3016` |
| `PrivilegeControl.dll` | `06FBD3337FAB9CE541F9030803468B7759935E152FB814E99F1C15CE9FA82D73` |

The Release build is not byte-reproducible: another build of the same source
gives other hashes, so these identify the measured files, not the source.

## Local validation

Four configurations in separate processes with the CI wrappers: Windows
PowerShell 5.1 and PowerShell 7, each elevated and as a basic user through
a restricted token. Each discovered 1,310 test cases (914 at `f11ff41`),
and no test failed. The instrumented coverage runs that followed gave the same
counts.

| Configuration | Passed | Failed | Skipped | Total |
| --- | ---: | ---: | ---: | ---: |
| Windows PowerShell 5.1, elevated | 1,286 | 0 | 24 | 1,310 |
| Windows PowerShell 5.1, basic user | 1,076 | 0 | 234 | 1,310 |
| PowerShell 7, elevated | 1,255 | 0 | 55 | 1,310 |
| PowerShell 7, basic user | 1,045 | 0 | 265 | 1,310 |

Skip eligibility is checked by row, not by name. NUnit keeps the placeholders
of a skipped data row, so skipped and executed names do not match. Each
configuration ran the suite once more in one Pester process, and every row
was recorded with its file, line, path, name, data, and result. The skipped
rows were 24, 234, 55, and 265, the same counts as in the validation runs.
The 578 skipped rows are 137 distinct tests, 350 of them rows with data.
Every skipped row has the same test, with the same data, executed in two
other configurations; no skipped row lacks an executed counterpart.

## Coverage

AltCover 9.0.145 OpenCover report of the frozen source, with the method of
the `3442194` baseline: the four configurations ran one after the other
without `--save`, from copied Release assemblies with their PDBs, AlphaFS and
System.Management.Automation excluded, and `runner --collect` recalculated
the report. The ratios are visited sequence or branch points divided by their
totals, not unique source lines.

| Assembly | Sequence points | Sequence coverage | Branch points | Branch coverage |
| --- | ---: | ---: | ---: | ---: |
| NTFSSecurity | 1,912/2,168 | 88.19% | 683/1,094 | 62.43% |
| Security2 | 1,055/1,225 | 86.12% | 506/742 | 68.19% |
| ProcessPrivileges | 205/219 | 93.61% | 72/125 | 57.60% |
| PrivilegeControl | 20/22 | 90.91% | 12/17 | 70.59% |
| Aggregate | 3,192/3,634 | 87.84% | 1,273/1,978 | 64.36% |

| Measurement | Sequence points | Branch points |
| --- | ---: | ---: |
| `3442194`, the baseline of this work | 2,641/3,559 (74.21%) | 974/1,933 (50.39%) |
| `73a0a7e` | 2,826/3,563 (79.32%) | 1,091/1,935 (56.38%) |
| `360417a` | 2,860/3,566 (80.20%) | 1,105/1,939 (56.99%) |
| `51412e0` | 3,067/3,566 (86.01%) | 1,192/1,939 (61.48%) |
| `d0acda3` | 3,079/3,566 (86.34%) | 1,207/1,939 (62.25%) |
| `3c19747` | 3,133/3,592 (87.22%) | 1,250/1,966 (63.58%) |
| `ae3078f` | 3,134/3,592 (87.25%) | 1,252/1,966 (63.68%) |
| `40bf6a8` | 3,166/3,626 (87.31%) | 1,257/1,977 (63.58%) |
| `a50070a` | 3,168/3,626 (87.37%) | 1,259/1,977 (63.68%) |
| `7aa8315` | 3,168/3,626 (87.37%) | 1,257/1,975 (63.65%) |
| `d61dffa` | 3,192/3,634 (87.84%) | 1,273/1,978 (64.36%) |
| `5a5d58b`, final | 3,192/3,634 (87.84%) | 1,273/1,978 (64.36%) |

- The sequence-point ratio rose from 74.21% to 87.84%, and the number of
  unvisited points fell from 918 to 442. The production code changed as well
  (3,559 to 3,634 points, because of the fixes), so the ratios are not
  increments of one source.
- The branch summary counts 820 compiler-generated points (patterns such as
  `foreach` and `using`), of which only 185 are visited. The explicit branch
  points that a person wrote are 1,088/1,158 (93.96%).
- The interim measurements stopped at the commits that are named; they show
  the progress, not a different method. `d61dffa` and `5a5d58b` give the same
  counts: the commits between them changed tests, documentation, and the
  wording of one code comment only.

## What the work changed

### Tests

136 `It` blocks were added; with data rows the suite grew from 914 to
1,310 cases per configuration. The tests assert state on disk, error ID,
category and target, continuation after a failure, the owner of the item, and
that a failed item writes no success-shaped object.

| Area | Test files | New `It` blocks |
| --- | --- | ---: |
| Public rule, identity, descriptor, and comparison objects, inheritance helpers, privilege objects, the extension methods | ObjectApis | 46 |
| Token handles, the privilege enabler and its finalizer, privilege control, the Init script, a privilege that a later command interrupts | Privileges | 17 |
| Item cmdlets, filters and their dot rules, depth, links, hard links, root-drive changes, disk space | ItemCmdlets, DriveRoot, Links | 24 |
| Access, audit, inheritance, owner, hash, and path errors; deny entries without rights; a NULL DACL | Access, Audit, Inheritance, Owner, FileHash, PathErrors | 25 |
| Security descriptors | SecurityDescriptor | 3 |
| A later command that ends the pipeline, for all 30 cmdlets and for the verbose, debug, and error streams | PipelineControl | 15 |
| The test helpers | TestHelpers | 6 |

### Defects found and fixed

| # | Defect | Fixed in | Regression guard |
| --- | --- | --- | --- |
| 1 | Public rule constructors lost the supplied path; simplified audit entries kept `ReadData` and were compared with access entries; boxed privilege values were compared wrongly | `b14c90b` | ObjectApis.Tests; 8 rows in each configuration |
| 2 | `Clear-NTFSAccess -DisableInheritance` and `Set-NTFSSecurityDescriptor` reported `RestoreOwnerError` for an owner that had not changed | `c7a0383` | PathErrors and SecurityDescriptor tests; 2 rows in each configuration |
| 3 | `InheritedFrom` read `unknown paren` and showed it for explicit entries | `2909a1c` | Access and Audit tests; 2 rows in the elevated configurations and 1 in the basic ones (the audit row needs the privilege) |
| 4 | Nine cmdlets handled the end of the pipeline (`break`, `continue`, `Select-Object -First`) as a failure of the item and went on; `Remove-Item2 -PassThru \| Select-Object -First 1` removed every item | `c77ecbf` | PipelineControl.Tests; 42 rows in each configuration: 35 for the nine cmdlets, 2 for the error of a nested folder, and 5 that pin the new check by type |
| 5 | `Get-ChildItem2 -Filter` read a bracket as a character class, so `Report[1].txt` was not found by its name | `ee7c105` | ItemCmdlets.Tests; 1 row in each configuration |
| 6 | A null `-Filter` ended in a `NullReferenceException`; introduced by fix 5 and never released | `ae3078f` | ItemCmdlets.Tests; 1 row in each configuration |
| 7 | A `throw` of a later command reaches a cmdlet through its Write call as an ordinary exception; the catch for the failures of an item reported it as the error of the item and went on, so that `Remove-Item2` removed the next item and the caller never saw the exception. Fix 4 found only the end of the pipeline by its type. `Set-NTFSSecurityDescriptor`, `Get-FileHash2`, and `Set-NTFSOwner` caught it also at a verbose or debug message | `40bf6a8` | PipelineControl.Tests; 16 rows in each configuration: 9 for a `throw` of the later command, 5 for a verbose or debug message, and 2 for a thrown type that a cmdlet handles. The rows for `Write-Error -ErrorAction Stop` of the later command turn green with fix 4, not with this one |
| 8 | `Get-ChildItem2 -Filter *.*` dropped the items without a dot in their names, most folders among them, so a listing with that filter missed them | `40bf6a8` | ItemCmdlets.Tests; 1 row in each configuration; found by a probe and by the independent review |
| 9 | The failed lookup of `InheritedFrom` leaked its native buffer | `40bf6a8` | none: no observable behavior, and the fallback tests run the path |
| 10 | `Get-ChildItem2` swallowed what a later command threw for an error that the cmdlet wrote for a nested folder, for example `Get-ChildItem2 -Recurse -File 2>&1 \| ForEach-Object { throw 'x' }`: the recursion took it for a failure of the folder above, wrote a verbose message, and ended the listing early, and the caller never saw the exception | `d44a200` | PipelineControl.Tests; 1 row in each configuration. The `break`, `continue`, and `-ErrorAction Stop` cases on the same error pass before and after |
| 11 | A cmdlet that enables the privileges left a privilege enabled when a later command ended the pipeline (`5>&1 \| Select-Object -First 2`) or threw at the debug message after the enabling: it noted the privilege only after that message, and `TryEnablePrivilege` took the exception for a failure to enable it and went on, so that all four privileges stayed enabled and the exception was lost | `d44a200` | Privileges.Tests; 2 rows in the elevated configurations (they need the privileges) |

Fixes 4, 7, and 10 changed the catch blocks of 10 cmdlets (`Get-DiskSpace`
now writes outside its try). Fixes 7 and 10 added a record of the exception
that the `WriteObject`, `WriteError`, `WriteVerbose`, and `WriteDebug`
methods of `BaseCmdlet` raise, which every catch-all that writes directly
passes on. `WriteWarning` is not noted: no catch-all encloses it. A scan of
the source finds 85 catch-all handlers under `NTFSSecurity\`. Sixteen of
them enclose a Write call directly in their try block: eleven pass the
exception on, and the other five are the Write methods themselves, which
record it and rethrow. Seventeen enclose only a helper, `InvokeAsOwner` or
`WriteChangesAsOwner`, whose owner restore can write a `RestoreOwnerError`;
they do not pass the exception on (open item 8). The scan is a text match
and cannot see a write inside another helper. The type check
`PipelineControl.IsEnd` remains as a second line of defense (open item 9).

### Red before, green after

The last column of the table above counts the test rows that fail on the
production code before a fix and pass after it. The first runs that showed
this were taken as each fix was written, with the tests of that commit. Their
logs were deleted with the temporary run folders, so their counts could not be
reproduced, and they are not used here. The evidence was measured again with
the final tests.

The eight test files that guard the fixes (ObjectApis, Access, Audit,
PathErrors, SecurityDescriptor, PipelineControl, ItemCmdlets, and Privileges:
650 cases per configuration) were laid over the production code of ten states
of the branch: the base `f11ff41`, the commit of each fix, the refactoring
`7aa8315`, and `d44a200`, the last commit that changes behavior. Each state was
built in Release in a separate worktree and run in the four configurations
with the focused runner of this work, the one that the mutation rounds use. It
runs only these eight files with its own Pester configuration, sets
`$ErrorActionPreference` to `Stop` like the CI wrappers, starts the basic runs
with `runas /trustlevel:0x20000`, and writes no NUnit file. A row that fails
at a state and passes at the next one is a guard of the fix between them; a
row that passes before and fails after would be a break.

| Step | Defects | Rows red before and green after: elevated 5.1, elevated 7, basic 5.1, basic 7 | Test files |
| --- | --- | --- | --- |
| Rows red at the base `f11ff41` | all | 76, 76, 73, 73 | |
| `f11ff41` to `b14c90b` | 1 | 8, 8, 8, 8 | ObjectApis |
| `b14c90b` to `c7a0383` | 2 | 2, 2, 2, 2 | PathErrors, SecurityDescriptor |
| `c7a0383` to `2909a1c` | 3 | 2, 2, 1, 1 | Access, Audit |
| `2909a1c` to `c77ecbf` | 4 | 42, 42, 42, 42 | PipelineControl |
| `c77ecbf` to `ee7c105` | 5 | 1, 1, 1, 1 | ItemCmdlets |
| `ee7c105` to `ae3078f` | 6 | 1, 1, 1, 1 | ItemCmdlets |
| `ae3078f` to `40bf6a8` | 7, 8, 9 | 17, 17, 17, 17 | ItemCmdlets, PipelineControl |
| `40bf6a8` to `7aa8315` | none (refactoring) | 0, 0, 0, 0 | none |
| `7aa8315` to `d44a200` | 10, 11 | 3, 3, 1, 1 | PipelineControl, Privileges |
| Rows red at `d44a200`, the control | none | 0, 0, 0, 0 | |

The steps add up to the rows that are red at the base, and no row passes at one
state and fails at the next in any configuration. At `d44a200` no row of the
650 fails in any configuration; the production code after it differs only in
an XML comment of `BaseCmdlets.cs`. The counts are of rows, not of names:
three rows that Pester lists under one unexpanded template name (see below)
make a count of names two lower for the first four states. In all 40 logs (10
states, 4 configurations), the failed count of the `RESULT` line, the number
of `FAILEDTEST` lines, and the rows in the CSV file agree. The commit that
each state was built from is the `source=` line of its build log, and it equals
the commit that the table names for all ten states; the assemblies of the
states were not hashed, because each build rewrote the hash file of the
frozen runner.
[`Quality-Gate-Paths-2026-10-09-RedGreen.csv`](Quality-Gate-Paths-2026-10-09-RedGreen.csv)
lists each guard test with its test file and its rows per configuration, and
[`Quality-Gate-Paths-2026-10-09-RedGreen-Logs.csv`](Quality-Gate-Paths-2026-10-09-RedGreen-Logs.csv)
lists the 40 logs with their sizes and SHA-256 values.

- Of the 42 rows of fix 4, 37 call the cmdlets. The other five pin the new
  check by type, `IsEnd`, through reflection, and are red before only because
  that check did not exist. Three of them are the rows of one data-driven
  test; the `BeforeAll` of their block fails without the type, so Pester
  lists them under the unexpanded template name.
- The 17 rows of the step to `40bf6a8` are 16 for defect 7 and one for defect
  8, the `*.*` row. Defect 9 has no row.
- The audit row of fix 3 and the two rows of fix 11 need the privileges. They
  are skipped in the basic configurations, and the eligibility check shows
  that each of them is executed in the elevated ones.
- The matrix ran the verbose and debug rows of defect 7 as they are, with
  `-ErrorAction SilentlyContinue`. They need it: under `Stop` and without it,
  a handler that reports the exception of the later command as an error of the
  item ends the pipeline with it, and the row cannot tell that from passing
  the exception on (the mutations M19 and M20 escaped for this reason at
  `d61dffa`, see below).
- One of these rows fails without a message before fix 7, in all four
  configurations: `Set-NTFSSecurityDescriptor`, verbose message,
  `Select-Object -First 1`. The other rows name what they expected. The
  matrix alone does not say why this one fails. The attribution to fix 7 rests
  on the source and on a mutation: at `ae3078f` the verbose message is written
  inside a try whose catch reports the exception as `WriteSdError` and goes on
  (`SetSecurityDescriptor.cs`, lines 47, 51, and 68), and the mutation M16,
  which removes that pass-on at the final source, fails this row with the same
  empty message in all four configurations.
- The matrix lays the final tests over earlier production code. It shows that
  a guard fails without its fix and passes with it, not how the test looked
  when it was first written, and a test that needs two fixes flips at the
  later step. The rows that pass at the base are characterization tests and
  tests of behavior that no fix changed; the mutations of the next section,
  not this matrix, show that they detect a change.

### Where a test or a classification was wrong

These cases are why an explanation below is a claim with evidence, not a
fact.

- The first version of the restored-owner test passed without reaching the
  retry, because a deny entry for the user does not stop an owner. It now
  uses an OWNER RIGHTS deny and asserts that a plain write is denied.
- The `continue` after the second name comparison of `Get-ChildItem2` was
  first classified as defensive. A probe showed that `*.*` reaches it, which
  led to defect 8.
- A mutation that removed that comparison escaped at `630926f`, and
  checking why exposed defect 5.
- The throw rows that the independent review asked for exposed defect 7.
- The review claimed that `Get-ChildItem2 -Recurse -ErrorAction Stop`
  swallows the error of a nested folder. A probe on the build of `7aa8315`
  showed that this error reaches the caller in both editions (a pipeline
  stop, which the catch already passes on). The same cause was real for a
  `throw` of a later command that takes the error through `2>&1`, which is
  defect 10; the review withdrew the claim.
- Three tests that take the error of a nested folder through `2>&1` relied
  on the default error action and failed in the first frozen run, because
  the CI wrappers set `$ErrorActionPreference` to `Stop`. The focused runner
  of this work had not set it. It does now, and the tests name
  `-ErrorAction Continue`.
- With the runner at `Stop`, the mutation rounds at `d61dffa` showed that the
  verbose and debug `throw` rows of the later-command tests ran without an
  error action. Under `Stop`, the handler that reports the exception of the
  later command as an item error ends the pipeline with it, and the row
  cannot tell that from passing the exception on. Two mutations escaped (the
  verbose record in two configurations, the debug record in all four). The
  red evidence of defect 7 for these rows had been taken with the default
  preference, so at CI they would not have been red. The rows now name
  `-ErrorAction SilentlyContinue`, the rounds ran again, and the matrix above
  shows these rows red before `40bf6a8` under a runner that sets `Stop`.
- The first Init-script tests asserted only the state of the Backup
  privilege. With the module setting `$true` the module enables the
  privileges before the cmdlet runs, so the branch that the test names could
  not fail it; the review predicted the mutation that then escaped (the
  condition of that branch). The tests now also assert the verbose message
  that only the cmdlet writes.
- A test variable named `$forEach` is the automatic variable of `foreach`
  and was empty inside Pester.
- A `Get-Acl` precondition for the hard-link test failed in the elevated
  configurations: the permissions were read despite the deny entries. The
  claim about them was dropped instead of asserted.
- Explanation rules that were wrong, or too strong, before they were
  checked by probes and the review: a rule listed the `Extensions.ForEach`
  and `GetParent` helpers as unused (the static scan does not see calls of
  generic methods, which hid the callers of `ForEach`, and the rule did not
  use the result of the scan for `GetParent`, which `Get-NTFSSimpleAccess`
  calls), so both are tested directly now; the catch-all rule said that no
  input could trigger it (a deny entry without rights does, and so does a
  full ACL); the effective-access rule said that the library never throws
  (the descriptor read is outside its try); the retry of the hash cmdlet
  cannot be made to succeed with an OWNER RIGHTS entry, because Windows drops
  it when the owner changes (probe); a dangling junction is read as the link
  itself and triggers nothing (probe); a NULL DACL does reach the branch that
  was called unreachable, and is tested; the hard-link rule said that no file
  ACL is checked, which the probe shows only for the refused data.

## Do the new tests detect faults?

Bounded mutations change one statement of a frozen copy of the source, rebuild
it, and run the guarding tests in the four configurations. A mutation is
detected when its guard test fails. The source is restored exactly (the
diff of the frozen copy is empty) and Release is rebuilt before any green
validation. The mutations of a round are applied together only when no
guard can fail because of another mutation of the round; the failures that
no guard of the round names are listed in the logs and are the collateral of
the mutations (for example, the `throw` rows next to the `Select-Object` rows
that guard the same catch).

Final rounds on the frozen source `5a5d58b`: 26 mutations in four rounds.
Twenty-five are detected by their guard test in every configuration where
that test runs (2 of 2 for the guards that need the privileges). The 26th,
M25, is an equivalent mutant and survives as expected: with the check by type
(`IsEnd`) removed from `IsFromLaterCommand`, the recording of the write
methods still passes on every exception that a test can raise, so no test
fails; the direct tests of `IsEnd` pin its rules (open item 9). The failures
that no guard of a round names are the other tests of the mutated code: in
round 3, the Init test for `$false` under M28, the privilege test that
throws at the debug message under M26, and the audit test for the error
category under M34. M25 has none.

| Round | Mutation | File | Change | Guard | Detected |
| ---: | --- | --- | --- | --- | --- |
| 1 | M10 | `BaseCmdlets.cs` | `IsEnd` no longer recognizes a flow-control exception by the name of its base type | Should recognize an exception whose base type is the flow control exception of PowerShell | 4/4 |
| 1 | M12 | `GetChildItem2.cs` | `[ValidateNotNull]` removed from `-Filter` | Should reject a null -Filter | 4/4 |
| 1 | M13 | `SetSecurityDescriptor.cs` | the previous owner is not set back after a write that took ownership | Should set a previous owner back that the user can assign after the write that took ownership | 2/2 |
| 1 | M14 | `FileSystemAccessRule2.RemoveFileSystemAccessRules.cs` | a deny entry is not removed from a descriptor | Remove-NTFSAccess should remove a deny entry from the descriptor and leave the item unchanged | 4/4 |
| 1 | M16 | `SetSecurityDescriptor.cs` | the catch no longer passes on the exception of a later command | Set-NTFSSecurityDescriptor should stop at the verbose message for Select-Object -First 1 of the later command | 4/4 |
| 1 | M17 | `GetFileHash2.cs` | the catch no longer passes on the exception of a later command | Get-FileHash2 should stop at the verbose message for Select-Object -First 1 of the later command | 4/4 |
| 1 | M22 | `GetChildItem2.cs` | the second comparison of the name with the pattern is skipped | Should return only the items that match the whole pattern for -Filter *.*.* | 4/4 |
| 1 | M23 | `BaseCmdlets.cs` | `WriteError` no longer records its exception | Should pass on what a later command throws when it takes the error of a nested folder | 4/4 |
| 1 | M27 | `BaseCmdlets.cs` | `TryEnablePrivilege` no longer passes on the exception of a later command | Should pass on what a later command throws at the message after the enabling and disable the privileges | 2/2 |
| 2 | M11 | `GetChildItem2.cs` | `*.*` is no longer treated as `*` | Should return every item for -Filter *.*, also the ones without a dot in their names | 4/4 |
| 2 | M18 | `BaseCmdlets.cs` | `WriteObject` no longer records its exception | Copy-Item2 should stop for a terminating error (throw) of the later command | 4/4 |
| 2 | M19 | `BaseCmdlets.cs` | `WriteVerbose` no longer records its exception | Get-FileHash2 should stop at the verbose message for throw of the later command | 4/4 |
| 2 | M20 | `BaseCmdlets.cs` | `WriteDebug` no longer records its exception | Set-NTFSOwner should stop at the debug message for throw of the later command | 4/4 |
| 2 | M7 | `GetChildItem2.cs` | the catch of the recursion no longer passes on the exception of a later command | Get-ChildItem2 should leave the loop for break after its first object | 4/4 |
| 2 | M8 | `RemoveItem2.cs` | the catch no longer passes on the exception of a later command | Remove-Item2 should leave the loop for break after its first object | 4/4 |
| 2 | M9 | `BaseCmdlets.cs` | `IsEnd` no longer recognizes `PipelineStoppedException` | Should recognize a PipelineStoppedException | 4/4 |
| 3 | M25 | `BaseCmdlets.cs` | `IsFromLaterCommand` without the check by type (`IsEnd`) | none: expected to survive | 0/4, as expected |
| 3 | M26 | `BaseCmdlets.cs` | `EnablePrivilege` notes the privilege after the debug message again | Should disable the privilege when Select-Object -First ends the pipeline at the message after its enabling | 2/2 |
| 3 | M28 | `OtherCmdlets.cs` | `Enable-Privileges` in the Init script tests `EnablePrivileges == false` | Should enable the privileges when the module setting EnablePrivileges is $true | 2/2 |
| 3 | M29 | `FileSystemAccessRule2.GetFileSystemAccessRules.cs` | the index guard of the `InheritedFrom` sources is removed | Should return the one entry that .NET reports for a NULL DACL, without a source | 4/4 |
| 3 | M30 | `Extensions.cs` | `ForEach` accepts a null source | ForEach should reject a source that is null | 4/4 |
| 3 | M31 | `Extensions.cs` | `GetParent` returns a `DirectoryInfo` for a parent path that names a file | Should return a parent path that names a file as a FileInfo of AlphaFS | 4/4 |
| 3 | M32 | `AddAccess.cs` | the loop goes on to `-PassThru` after an `AddAceError` | Add-NTFSAccess, a deny entry without rights: Should write an AddAceError | 4/4 |
| 3 | M33 | `RemoveAccess.cs` | another ID for the `RemoveAceError` | Remove-NTFSAccess, a deny entry without rights: Should write a RemoveAceError | 4/4 |
| 3 | M34 | `AddAudit.cs` | another category for the `AddAceError` | Add-NTFSAudit, rights None: Should write an AddAceError | 2/2 |
| 4 | M24 | `BaseCmdlets.cs` | `IsFromLaterCommand` is always false | Should leave the loop for a break of a later command that takes the error of a nested folder | 4/4 |

Rounds at earlier commits found what these repeat. At `630926f`, nine of ten
mutations were detected; the one that escaped, the second name comparison of
`Get-ChildItem2`, exposed defect 5. At `ae3078f`, four more were detected. At
`a50070a`, seven of nine were detected: M11 escaped because another mutation
of the same round bypassed the same line (my overlap, so it moved to another
round), and M21 was an equivalent mutant, an exception filter that no
exception can reach, which `7aa8315` removed. At `d61dffa` the 26 mutations
above ran once and three escaped: M19 and M20, because the verbose and debug
rows ran under the error action of the CI runner, and M28, because the Init
test could not fail for the branch it names. `f4a16e1` fixed the tests, and
the rounds above ran again at the final source. Each round restored the
source exactly (the diff of the frozen copy was empty) and rebuilt Release.

## The remaining unvisited code

The aggregate report leaves 231 methods with 442 unvisited sequence points
and 70 unvisited explicit branch points; at `3442194` it left 918 sequence
points. Every method is classified and none is unclassified: 223 are
explained and 8 are open for the maintainer. The largest explained blocks
are the 103 one-line getters of cmdlet parameters, the registry model that no
cmdlet uses (105 points), the ownership retry of an audit write (47 points),
the unused native handle wrappers (34 points), and the catch-all of the
per-item loops (32 points).

| Category | Disposition | Methods | Unvisited sequence points | Unvisited explicit branch points |
| --- | --- | ---: | ---: | ---: |
| unused by cmdlets | Explained | 60 | 173 | 34 |
| parameter/API surface | Explained | 103 | 103 | 0 |
| defensive | Explained | 33 | 77 | 16 |
| environment-specific | Explained | 27 | 81 | 18 |
| unused by cmdlets | Open | 8 | 8 | 2 |
| **Total** | | **231** | **442** | **70** |

The explanation of every rule is in
[Quality-Gate-Paths-2026-10-09-Explanations.md](./Quality-Gate-Paths-2026-10-09-Explanations.md),
each with its evidence (an executed probe, a static scan of the compiled
code, or reading the source), its residual risk, and the tests that run the
neighboring paths. [The method rows](./Quality-Gate-Paths-2026-10-09-Methods.csv)
give, for every method, the source file, the unvisited lines, the number of
unvisited sequence and branch points, whether a cmdlet reaches it in the
compiled code, and its rule. "Explained" means a source-backed explanation
exists, not that a test runs the path. The scan behind the column "reachable
from a cmdlet" reads the compiled code and does not see calls of generic
methods: it reported `Extensions.ForEach` as unreachable although cmdlets
call it. Treat that column as a hint, not as evidence.

## Per-cmdlet coverage

[The cmdlet rows](./Quality-Gate-Paths-2026-10-09-Cmdlets.csv) give the
sequence and branch points of each of the 36 cmdlets, including their
closures. Every cmdlet has 72.5% or more of its sequence points visited. The
lowest are `Clear-NTFSAudit` (72.5%), `Disable-NTFSAuditInheritance` and
`Enable-NTFSAuditInheritance` (73.5%), `Add-NTFSAudit` (75.7%), and
`Remove-NTFSAudit` (75.9%): their unvisited points are the retry after an
access denial, which a local audit write never raises (rule
AUDIT-OWNER-RETRY). `Get-NTFSSecurityDescriptor` (77.8%) has the catch-all of
its loop and the closure of its owner retry, `Get-NTFSEffectiveAccess`
(80.3%) the catch blocks around a library that hides its own failures, and
`Get-NTFSInheritance` (80.9%) the catch and the retry of its loop.

### Parameter sets

The 36 cmdlets have 64 parameter sets, and 20 of the cmdlets have several:
path or security descriptor, and for the four cmdlets that add and remove
entries also simple or complex. Two kinds of evidence exist; neither is a
matrix of judged error and state tests for each set.

- A parser-based scan of the test files counts, for each set, the
  invocations that can only bind it
  ([the sets](./Quality-Gate-Paths-2026-10-09-ParameterSets.csv)). Fifty-seven
  sets have at least one. Seven have none, because their tests splat the
  parameters, pipe the descriptor, or call the command through a variable:
  `Add-NTFSAudit` (SDSimple), `Get-NTFSOrphanedAudit` (SD), `Get-NTFSOwner`
  (SecurityDescriptor), `Remove-NTFSAccess` (PathSimple and SDSimple), and
  `Remove-NTFSAudit` (PathSimple and SDSimple).
- No unvisited point lies on a parameter-set switch. The 20 cmdlets with
  several sets have 168 unvisited points, 165 sequence points and 3 branch
  points. Sixty-nine sequence points are property getters; the other 96
  sequence points and 3 branch points are catch handlers with their closing
  braces, their `WriteError` and `continue`, and the closures of the owner
  retry. None of them mentions `ParameterSetName`, the descriptor list, or
  `AppliesTo`.

## Open items for the maintainer

None of these was changed or reclassified as harmless.

1. `FileSystemSecurity2` converts from `FileSecurity` and `DirectorySecurity`
   through `FileInfo("")` and `DirectoryInfo("")`, so every conversion
   throws. No cmdlet uses it; fix or remove it.
2. `RemoveFileSystemAccessRuleAll` and `RemoveFileSystemAuditRuleAll` ignore
   their account list and remove every explicit entry (finding #113). No
   cmdlet passes an account list. The predicate of the discarded filter,
   `Count() > 1`, would match no account that appears once, so using its
   result as it stands would remove nothing.
3. The overloads of `AddFileSystemAccessRule` and `AddFileSystemAuditRule`
   for a path and several accounts are lazy iterators, so nothing is written
   until the caller enumerates the result; the overloads for an item and for
   a descriptor write at once.
4. A `PrivilegeEnabler` that enabled a privilege and was never disposed
   keeps the privilege enabled: a static list holds it, so its finalizer
   never runs.
5. `Get-ChildItem2 -Filter` matches names twice, in the AlphaFS enumeration
   and in the cmdlet, and their rules for a dot differ from those of
   `Get-ChildItem` (probe p32, both editions unless noted). `*.*` now means
   every item, but `Report.*` does not return the file `Report` and `Rep*.`
   returns nothing where `Get-ChildItem` returns `Report`; `Report.` returns
   nothing, as in PowerShell 7 but not in Windows PowerShell 5.1, which
   returns `Report`; an empty value returns nothing without an error. The
   documentation lists this and `ItemCmdlets.Tests` pins it, so a change is a
   decision. Decide whether to align the rules.
6. The registry model, the unused helper classes, and the raw descriptor
   readers have no caller (Decisions 21 and 22 govern them). Their
   explanations say so; removing them is your decision.
7. The ownership retry of an audit write over SMB has no test that a local
   volume can run: a local audit write never fails with access denied. The
   lab suite covers the cmdlets over SMB; gate 3 should repeat it.
8. Seventeen handlers enclose only a helper that can write a
   `RestoreOwnerError` (`InvokeAsOwner`, `WriteChangesAsOwner`) and do not
   pass on what a later command raises at that write. By reading the code,
   the handler then writes the error of the item, which raises again for
   `-ErrorAction Stop` and for a stopped pipeline, so those still end the
   command (not run); a later command that throws only for the
   `RestoreOwnerError` record would have its exception swallowed. Closing it
   means one check in each handler and a test with an owner that cannot be
   set back (elevated only).
9. The type check `PipelineControl.IsEnd` backs up the recording of the
   write methods for calls into PowerShell that nothing records, for example
   `ShouldProcess` in the try block of `Remove-Item2`. No test makes that
   call raise it, and the mutation that removes it is not detected (round 3);
   only direct tests of its type rules cover it. Keep it as defense in depth
   or remove it.
10. The catch of `Enable-Privileges` that rethrows a `ParseException` for a
    malformed module setting is unvisited: the base class casts the same
    value first.
11. By reading the source, the `-SecurityDescriptor` sets of the four cmdlets
    that add and remove entries have no handler around the change: an
    exception, such as one for a deny entry without rights, ends the cmdlet
    with a terminating error, where the `-Path` sets write an error for the
    item and go on. The probe of a full ACL ran into it with
    `-SecurityDescriptor`. The zero-mask tests use `-Path` only. Whether the
    descriptor sets should report per item is a design decision.
12. The test helpers `Add-TestDenyRule`, `Set-TestOwner`, and
    `Block-TestReadPermission` and `Block-TestWritePermission` accept an
    existing link as the item: the check of `Assert-TestSandboxPath` covers
    the folders of the path, not the item. Only `Set-TestNullDacl` refuses a
    link. No test passes a link to them.
13. Decision 22 remains proposed, and the stable 5.0.0 gate stays open.

## Completion matrix

| Criterion of the handoff | Status | Evidence |
| --- | --- | --- |
| Every currently unvisited method is inventoried | Done | 231 methods in the CSV, none unclassified |
| Each path is tested or has a source-backed explanation | Done, with open items | explanations by rule; 8 methods stay open for the maintainer |
| Reachable gaps closed first, without duplicating earlier tests | Done | 136 new `It` blocks; defects 1 to 11 |
| Behavior tests before production changes | Not evidenced | each of the eight fix commits carries its tests and its fix together, and the red runs that were taken while the tests were written were deleted with their run folders; the order cannot be shown from the history or from kept logs. The first test of defect 8 pinned `*.*` as the design and was changed after a review finding |
| Regressions that fail without the fix | Done, with exceptions | the red/green matrix: 76 rows (73 in the basic configurations) fail at the base, each is green at the step of its fix, none breaks later; the mutations. Exceptions: defect 9 has no guard; the guards of defect 11 and the audit row of defect 3 run only elevated |
| All cmdlets and parameter sets have meaningful error and state tests | Partly | per-cmdlet coverage of 72.5% or more; the parameter-set evidence is a parser count and the coverage of the switches, not a matrix of judged tests |
| Full suite in both editions and privilege modes | Passed | 1,310 cases in each, zero failures |
| No required case is skipped across the matrix | Passed | 578 skipped rows, each executed in two other configurations |
| Frozen Release measurement with all four configurations | Done | source pin, XML, hashes, exclusions |
| Differences from the `3442194` baseline explained | Done | the coverage section |
| Self-review and one independent finished-diff review | Done, see the limits | the review section |
| Docs, help, changelog, Memory Bank | Done | `CHANGELOG.md`, cmdlet page, help, Memory Bank |
| Commit locally, no remote change | Done | the commits above; no push |

## Checks not run, and limits

- The lab suite, the published-package acceptance, and the OS matrix were not
  run here; they belong to gate 3.
- A matrix of error and state tests for each parameter set was not built.
  The evidence is described under [Parameter sets](#parameter-sets): a
  parser-based count of the test invocations and the coverage of the
  parameter-set switches. It does not judge how meaningful each test is.
- The explanations are not tests. Each one names its evidence; an
  explanation that rests on reading the source only says so.
- The custom `security-reviewer` agent could not start because of its
  configured model, and no model setting was changed. The built-in read-only
  `code-review` agent made the static review passes below; none of them built
  or ran anything.
- The coverage percentages are not a measure of the quality of the
  assertions; the mutations are the measure for the new tests. A mutation
  that is not detected is reported, not hidden.
- The CI scripts set `$ErrorActionPreference` to `Stop`, and a test that
  relies on a non-terminating error must name its error action. The tests
  were checked for this by reading and by the mutation rounds, and the
  focused runner of this work sets `Stop` too, but nothing enforces it: a new
  row without an error action would regain the weakness silently. A test
  that every `Run` block of `PipelineControl.Tests` names one is a possible
  hardening that was not added.
- The red/green matrix measures the final tests on older production code. It
  does not show the order in which a test and its fix were written; the red
  runs of that time were not kept. The ten states are identified by the
  commit of their build, not by hashes of their assemblies.
- All runs are on one Windows Server 2025 host. The privileged tests skip
  without the privileges and run elevated, so a basic-user run cannot show
  them; the eligibility check shows that each of them runs elsewhere.

## Handoff to gate 3

Repeat the affected acceptance on the packaged candidate before it is
published. Each fix changes behavior that the lab can observe:

| Fix | What to repeat |
| --- | --- |
| `c7a0383` | `Clear-NTFSAccess -DisableInheritance` and `Set-NTFSSecurityDescriptor` on an item that the user owns, over SMB: no `RestoreOwnerError` |
| `2909a1c` | `Get-NTFSAccess` and `Get-NTFSAudit` with `GetInheritedFrom` for an item whose parent folder is unreadable |
| `c77ecbf`, `40bf6a8`, `d44a200` | `Remove-Item2`, `Copy-Item2`, `Move-Item2`, `Set-NTFSOwner`, `Set-NTFSSecurityDescriptor`, and `Get-ChildItem2` with `Select-Object -First 1`, `break`, and a `throw` of a later command, also on the verbose, debug, and error streams: no further item changes, and the caller sees the error |
| `d44a200` | `Get-NTFSOwner` or `Get-NTFSAccess` with the debug stream taken by `Select-Object -First 2`: the Take Ownership privilege is disabled again afterwards (elevated) |
| `ee7c105`, `ae3078f`, `40bf6a8` | `Get-ChildItem2 -Filter` with brackets, `*.*`, and a null value on a share |
| `b14c90b` | the rule, audit, and privilege objects in the packaged module |

## Review

The custom `security-reviewer` agent could not start because of its
configured model, and no model setting was changed. A built-in read-only
`code-review` agent made nine static passes: seven over the diff in ranges,
which also read the draft appendix and the draft report; a read of the final
report, the appendix, the tables, the Memory Bank notes, and the lab README;
and a read of the red/green evidence against its raw logs. It built and ran
nothing. No pass found a Blocker or a Major issue. Every finding was either
fixed, turned into an open item, or answered with a probe; one finding
(`-ErrorAction Stop` swallowed by the recursion) was refuted by a probe and
withdrawn by the reviewer.

| Pass | Range | Findings (Minor unless stated) | What became of them |
| ---: | --- | --- | --- |
| 1 | `f11ff41..cd56f49` | A break or continue test whose first output was above the recursion, so it never reached the frame where `Get-ChildItem2` swallowed both; tests that pinned the lazy path overloads as correct; a `PrivilegeEnabler` test without `finally`; three Nits | defect 4 for every cmdlet; open item 3; `finally` added |
| 2 | `cd56f49..630926f` | No test for the sandbox guard of the drive-mapping helper; its drive letter collided with two tests; no `throw` or `-ErrorAction Stop` row, which the engine could deliver as another exception | guard tests, the free-letter choice, and the rows that found defect 7 |
| 3 | `630926f..ae3078f` | `*.*` pinned as design; a restored-owner test that could pass without reaching the restore; the help dropped the asterisks of the `-Filter` paragraph; wording (Nit) | defect 8; a precondition in the test; the paragraph rewritten for platyPS |
| 4 | `ae3078f..40bf6a8` and the first appendix | The recording of the write methods judged sound; gaps in how handlers were counted; eight rules doubted with evidence | handlers and rules corrected, the tests of this report added |
| 5 | `40bf6a8..7aa8315` and the draft report | The draft described an older commit; the check by type had no behavior test; wording about "a later command" (Nits) | the report regenerated; reflection tests of the check by type; typed-throw rows |
| 6 | `7aa8315..d0bd1af` | The dot paragraph named the wrong layer; Init tests that could not fail for their branch; the first-nested-folder assertion; a link as the item of `Set-TestNullDacl`; wording (Nits) | `f4a16e1` and `5a5d58b` |
| 7 | `d0bd1af..5a5d58b` | A comment named three cmdlets where one calls `ShouldProcess` in a try block (Nit); optional: a test that every `Run` block names an error action | the comment fixed after the measured source; the guard test is not added (limits) |
| 8 | the final report, appendix, tables, Memory Bank notes, lab README | Four Minor: the production total left out `ProcessPrivileges`; the red runs of the fixes were not preserved, and "six `throw` cases" could not be reproduced; the hard-link rule stated more than its evidence; the Memory Bank said that AlphaFS follows the Windows dot rules. Nine Nits: the dot rule that depends on the edition, the count of unvisited points, the helper callers, the warning codes, the completion row together with the "test-first" wording of the Memory Bank, the wording "no test can make that call raise it", the trigger of a full ACL, and two missing items (the test helpers that accept a link, and the dependence on the ambient error action) | the numbers and wording corrected; the red evidence measured again (the red/green matrix above); the rule and the Memory Bank corrected; open items 11 and 12 and the limit about the error action added |
| 9 | the red/green section, its CSV, the completion row, the Memory Bank notes, against the 40 raw logs | Two Minor: the test file of defect 2 was named wrongly (PathErrors, not Access); the completion row said that tests came before the fixes, which no kept evidence shows. Four Nits: the focused runner was called the CI wrappers and its result an NUnit result; defect 7 read "a `throw` or a terminating error", where only the `throw` rows turn green with fix 7; one guard row fails without a message; the 40 logs had no fingerprint | the CSV has a test-file column and the step table follows it; the row is split into an order that is not evidenced and a guard that is measured; the wording corrected; the empty message explained by the source and the mutation M16; a manifest with the SHA-256 of every log |

Pass 8 checked the identity paragraph, the pass and skip table, the skipped
rows, the assembly and evidence hashes, the mutation table, the coverage and
category numbers, and the parameter-set counts against git and the CSVs, and
found them to agree; the production total was the one exception. Pass 9
recomputed the step table, the sub-counts of the defects table, and the
claims about the unexpanded name and about the production code after
`d44a200` from the raw logs and git, and found them to agree; its findings
are about the test file, the order of tests and fixes, and wording. The
corrections that followed pass 9 were checked by the author and by no other
pass. No pass is a substitute for the lab acceptance of gate 3.

## Evidence outside git

Raw evidence is local and not committed. It is in the session folder
`C:\Users\install\.copilot\session-state\4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files\qg-paths`:
the OpenCover XML of the four configurations and the aggregate, the NUnit
results of the Validate runs, the unvisited-method and unvisited-point
inventories, the per-row eligibility CSV files, the mutation logs, the logs of
the red/green matrix (the focused run of each of the ten states in the four
configurations), the probe scripts and their results, and the scripts that
produce the tables.

| File | SHA-256 |
| --- | --- |
| `coverage/coverage.xml` | `3EFAE43A574B62AB5DDC80022E52D28B8606E82F0BF9045BECB87B2ACBADB8D4` |
| `coverage/elevated-Desktop.xml` | `1DA9DAE5D5CDA1EB19079CFD69137EAC3314B8B926AD0D33C90026F2DE894B7D` |
| `coverage/basic-Desktop.xml` | `E43E7B457161E4C63A044215362694E5AB10AAE2AA3E057E459AD2033DA98462` |
| `coverage/elevated-Core.xml` | `DE329D7E640BD3E4F6C2DCC9EBF2217EF5E0E7F38C114738D0591FEBEAAEDD94` |
| `coverage/basic-Core.xml` | `55D167E4764A9EE5DA2EBBAE64C3E9776434D70144DD6C6A810DEA8890524AA6` |
| `validate/elevated-Desktop.xml` | `0FC57455840153FBCBAB53A1AEBF6ABA02088C3A647CD4116CAE29E23F587AAE` |
| `validate/basic-Desktop.xml` | `9E27622F9ED0A92948C6BF59DD46AEF8AB6D4BEBF45BEAE4B0DB2AFDDF5D3011` |
| `validate/elevated-Core.xml` | `1B8A5DB7A4A9337AAB5E63011E4807CCCC1C43BF1E171ADF3E15BB312AEED80E` |
| `validate/basic-Core.xml` | `BFA5D4BC57EBC36A108F465418D5567FF05A0E4BFBF2E7096E4F785CAC74E8C2` |
| `inventory-5a5d58b/unvisited-methods.csv` | `F5B736EDF662C9C0E3DEBD4302EE6F7A59DF0623FDCC2A479ECCA4C89773F007` |
| `inventory-5a5d58b/unvisited-points.csv` | `56AA0B5DDA67B45545CCCCEF41497CB300B54A487BAFB2CAA4EA4E0D024749A5` |
| `classification-5a5d58b.csv` | `E2CD8700C5C8DFB52D33D6E6DB96E3EBD630D94CB4A4D224B1BD1C1F356CECB0` |
| `eligibility-run-5a5d58b/skipped-rows.csv` | `AD584A885AB5C73B4E4CC7C3CF42CC92114C198E48ABE0D367BB001AB93E7489` |
| `measured-assemblies-5a5d58b.csv` | `A8030B7AD00E2B4632C88C46C336DFBC4873383A021F6B446DA4CED6462DA51C` |
| `mutations-5a5d58b-r1/mutation-results.csv` | `29D4E5EEC5FCCD91E8E2C1323C030A75691B5FA530C8345757729E9DCB58EC61` |
| `mutations-5a5d58b-r2/mutation-results.csv` | `87EC131C64C6F3AD0F440C41FA8CF0F0618E7875AAB5EC7D6A1C647CF361C98E` |
| `mutations-5a5d58b-r3/mutation-results.csv` | `05D7752A5C9B0DA5F5A3F35ED83C471FCEDDAE5EA967D557AA0AD334A02A244C` |
| `mutations-5a5d58b-r4/mutation-results.csv` | `EB774D4621658DFA8B4390FFC6201F913E88A214FB2510B69A5B9F50D922B18D` |
| `redgreen/redgreen-results.csv` | `C2327B991608489A85CC32CE17CC58F258348677EA31815F123D228AECBCB55A` |
| `redgreen/redgreen-failed-rows.csv` | `5AA4E1514F75CEEAACD8206F3E8C7727C2E970E2D45E7D545FD51F02EF21ED1F` |
| `redgreen/redgreen-guards.csv` (the CSV file of this folder with the red/green rows) | `D5D4720B2E6DA3619889C75DF3A2876E505FEED19BDD34695C92EF7421CD3558` |
| `redgreen/redgreen-summary.csv` | `46987DE40D526A279871E5F1915CDC346C576B3E644E169A1E3C79B7181B9052` |
| `redgreen/redgreen-log-manifest.csv` (the CSV file of this folder with the hash of each of the 40 logs) | `3E45ABFD850155F276DA5AF0E3FBEE83800D2C269DBB59B800042AC0080D4615` |
| `redgreen/redgreen-verify.csv` | `717AB27434D35A59750C35DB8B33F548FC6F7F3E01353F3BC290629516735DF7` |
| `redgreen/redgreen-driver.log` | `FCB9AE5980092BE97E362B2BE412CAE771C0EFB0CC326CBE814726A246D535EA` |
