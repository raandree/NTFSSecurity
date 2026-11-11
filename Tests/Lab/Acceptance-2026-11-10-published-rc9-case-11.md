# Acceptance of the published 5.0.0-rc9 with the live tests of case 11, 2026-11-10

An addendum to the
[acceptance of the published 5.0.0-rc9](Acceptance-2026-11-10-published-rc9.md).
That record ran the live tests of rc7 and rc8, which don't exercise what rc9
changed: it says that the unit suite does. This record adds case 11 to the live
tests, shows that its tests fail on the published rc8 for the expected reasons
and pass on the published rc9, and runs the same published bytes again in the
first lab, in the three cells of the operating-system matrix, and in the
module's own suite. It repeats neither the machines nor the method of the
earlier records; it adds what differs. It isn't a claim that the quality gate
is complete (see the limits at the end).

## Result

- The published 5.0.0-rc9 passed the extended kit in every stage. Its identity
  (the tag, the CI run, the Gallery hash, and the GitHub zip) was verified
  before the chains d1, d2, and a1, and the module of every run is the published
  package, whose `NTFSSecurity.dll` has the SHA-256 `464CAB36…` in the chain
  logs.
- Case 11 pins the changes of rc9 that the lab can observe: 191 tests per
  edition. On the published rc8, 79 of them fail, each for the expected reason,
  and the other 112 pass, as do the 245 tests of cases 1 to 10 that run (one
  more is skipped); on the published rc9, all pass.
- The live controller passed in the three cells of the matrix, both editions,
  every role: 2,520 passed, 0 failed, 12 skipped (420 / 0 / 2 per edition and
  cell). It passed in the first lab too: 436 passed, 0 failed, 1 skipped in each
  edition. Every role was validated from the result files, and the independent
  end-state check said CLEAN after each cell and after the first lab, for both
  labs at 00:45 UTC, and again for the matrix lab at 01:21 UTC, after the
  suites.
- The module's own suite, which has the 52 unit cases of this branch, passed in
  all 24 runs (six machine classes, two editions, elevated and as a basic
  user): 1,911 cases per configuration on the machines of the domain and on
  `OSWin11`, 1,910 on the host, 0 failed. In all 20 comparisons with the host,
  the skipped tests are the same, name for name.
- The counts of cases 1 to 10 equal those of the earlier record (1,374 / 0 / 12
  in the cells, 245 / 0 / 1 per edition in the first lab); case 11 adds 191
  passed tests per edition to each.
- The run came in two chains, because the evaluation client shuts itself down
  an hour after each start (see [Method](#method)). No host shutdown, no lost
  secure channel, and no repair of a machine happened.
- The run changed nothing in the module, the help file, or the manifest: it
  used the published package, and the kit is the commit named below.

## What case 11 tests

Case 11 of `Tests\Lab\NTFSSecurity.Live.Tests.ps1` has 191 tests in each
edition. They run in the roles that can observe the behavior, and the State
role checks on the file server, without the module, what the runs left. The
README of the kit has the case table.

| What rc9 changed | Tests | Roles | Per edition | Fail on rc8 | What rc8 did |
| --- | --- | --- | ---: | ---: | --- |
| A piped row with a bad `AccessType` (`Denyy`, the list `Allow, Deny`) writes one `InvalidParameterValue` error for its path, changes nothing there, and the next row is applied | `Add-NTFSAccess` with three rows | Delegate | 1 | 1 | wrote no error; `Denyy` created an `Allow` entry (the default), and of the list one value won |
| Valid rows by property name (domain accounts, `Deny`, `AppliesTo`, the flags) create those entries and keep the owner; `Remove-NTFSAccess` with a piped `Deny` row removes only the `Deny` entry | the folders of the case, `Add-NTFSAccess`, `Remove-NTFSAccess` | Delegate | 3 | 0 | the same |
| A named `$null` for `-AccessType` stops the command with `InvalidParameterValue`, before the first path | one path, two piped paths | Delegate | 2 | 2 | stopped with the error ID `ParameterBindingFailed` |
| A piped row with a misspelled `AuditFlags` writes `InvalidParameterValue` for its path and the next row is applied | `Add-NTFSAudit`, `Remove-NTFSAudit` | ServerAdmin, Admin | 4 | 4 | dropped the flags and used the default (`Success, Failure`): added an entry, or removed the one that the row should have kept |
| In a set of security descriptors, a change that throws for the first descriptor writes `AddAceError` or `RemoveAceError` for it, and the second is changed and written | `Add-NTFSAccess`, `Remove-NTFSAccess` | Delegate | 2 | 2 | the exception `Argument cannot be zero (accessMask)` ended the cmdlet |
| A later command that throws at the `RestoreOwnerError` record reaches the caller, and the next folder stays as it was; without a later command the cmdlet writes one `RestoreOwnerError` for the folder whose owner it took and changes both folders | 7 handlers, each in two styles, and the premise of the folders | Delegate | 15 | 7 | the cmdlet took the throw for an error of the item and went on with the next folder; the throw never reached the caller |
| `Get-ChildItem2 -Filter` follows the dot rules of Windows PowerShell 5.1: 10 literal results, 16 patterns against `Get-ChildItem` of Windows PowerShell 5.1 on the same share, and the 3 documented differences | the folder of each role | Delegate, ServerAdmin, Admin | 87 | 48 | matched each name again as a wildcard of PowerShell, so `Report.*`, `*.??`, `a?`, a dot at the end, and an empty filter returned other names or none |
| The overload of `AddFileSystemAccessRule` that takes a path adds the entry and keeps the owner | one folder | Delegate | 1 | 0 | the same (the test pins what rc9 keeps) |
| The State role finds the owners, the entry types of the subject, the audit flags, and the changes of each handler as the runs on the client should have left them | 38 owners, 14 entry types, 10 audit flags, 14 handlers | Server | 76 | 15 | the entries of the bad rows, the flags of the misspelled rows, the unchanged second descriptor, and the changed next folder |

That is 191 tests in each edition: 79 fail on rc8 and pass on rc9, and 112
pass on both. The tests that pass on both pin what rc9 keeps.

The 16 patterns and the 10 literal results agree with the file server's own
matching for all but the three differences that the page of the cmdlet
documents. Each was asserted by its own test, with the answer of Windows
PowerShell 5.1 in a child process as the account of the run:

- **An 8.3 short name.** `LONGFI~1*` returns `LongFileName.txt` with
  `Get-ChildItem` of Windows PowerShell 5.1, which matches the short name that
  the file server creates, and nothing with `Get-ChildItem2`, which matches the
  real name only. The test skips when the file server creates no short name for
  the file.
- **A blank at the end of the pattern.** `Report.* ` returns `Report` and
  `Report.txt` with Windows PowerShell 5.1, which drops the blank, and nothing
  with `Get-ChildItem2`, which keeps it as part of the pattern.
- **A pattern of two dots.** `..` stops with the error `DirArgumentError` in
  Windows PowerShell 5.1, and `Get-ChildItem2` accepts it and returns nothing.

### What has no live test

Ten of the 17 handlers that retry as the owner have no row, each for a reason of
Windows that the coverage report of the same branch explains
([the check that a later command raises](../Coverage/Quality-Gate-rc9-2026-11-10.md)):

| Handlers | Why the lab can't drive them into `RestoreOwnerError` |
| --- | --- |
| `Get-NTFSAccess`, `Get-NTFSOrphanedAccess`, `Get-NTFSEffectiveAccess`, `Get-NTFSInheritance` | The retry starts with `FileSystemOwner.GetOwner`, which needs the READ_CONTROL right whose denial started the retry, so it ends with a `ReadSecurityError` before it takes the owner. `Get-NTFSSecurityDescriptor`, which isn't one of the 17, is the same. |
| `Add-NTFSAudit`, `Remove-NTFSAudit`, `Clear-NTFSAudit`, `Enable-NTFSAuditInheritance`, `Disable-NTFSAuditInheritance` | They write the SACL, which doesn't depend on the DACL, so the first write never fails for a denied DACL, and an account without the Security privilege can't write it at all (error 1314, not the access denied that starts the retry). |
| `Get-FileHash2` | It needs the data of the file, which ownership doesn't grant. |

The seven that have a row are `Clear-NTFSAccess`,
`Disable-NTFSAccessInheritance`, `Enable-NTFSAccessInheritance`,
`Set-NTFSInheritance`, `Set-NTFSSecurityDescriptor`, `Add-NTFSAccess`, and
`Remove-NTFSAccess`. The
delegated group has Take Ownership on the folders of the case, and an owner may
change the DACL whatever a plain deny entry says. `Blocked` is a folder whose
DACL denies the group the right to change it, so the first write of a handler
fails, the retry takes the owner and writes, and the account, which holds no
Restore privilege on the file server, can't give Administrators back (error
1307): that is the `RestoreOwnerError` of each run.

Four changes of rc9 don't depend on where the item is, so they have no live
test either: `-SecurityDescriptor` of `Set-NTFSSecurityDescriptor` at position
1 (only the binder decides), the `EnablePrivileges` setting (a setting of the
client), the account list of `RemoveFileSystemAccessRuleAll` and
`RemoveFileSystemAuditRuleAll` (a library API that no cmdlet calls with a list),
and the argument completers (they run on the client). The new
`ReadSecurityError` of `Get-NTFSOrphanedAccess` for an item that it can't read
for another reason than a denied access has no trigger over SMB that was found
or built; the unvisited catch is explained in the coverage report.

## Candidate and kit identity

| | Published 5.0.0-rc9 | Published 5.0.0-rc8 |
| --- | --- | --- |
| Tag | `823c814908a048e1607816a1041dc63357e01dfe` | `c71919700c3fc48ac910f86f94f59ab2f5731add` |
| Identity check | `PUBLISHED_IDENTITY_VERIFIED` before the chains (22:58 and 23:51 UTC) | `PUBLISHED_IDENTITY_VERIFIED` at 23:22 UTC, CI run `39408140862` |
| `NTFSSecurity.dll` SHA-256 | `464CAB365AD63CD22208B21012A5B7F0B8B630E819CF300019787A0172791198` | `D8CB4015BF25379C77A645F82EEECA54F86219F228A5029E32E4D52FBD016E79` |
| Gallery package | the controller checked the SHA-512 that the Gallery publishes before each run | the same |

The kit is the commit `5a92d601f03c7a7833d78eb9fd504ea158ef8ee1` of the branch
of this record, frozen in a worktree at the start of the chains d1, d2, and a1:
the controller
`Tests\Lab\Invoke-NTFSSecurityLabTest.ps1` is the Git blob
`5d439867a10b0bdd8ddf800604210a9a3b906485`, and the live tests are the blob
`b59875de35fa937e78dea3ecf1b428ec843b1c4a`. The chains d1, d2, and a1 logged
the same two blobs, and a2 logged the commit of the worktree. The branch has
one later commit that touches a file of the kit: it
changes a comment of the live tests (the tokens of the file without comments
and line endings are equal), and the records and the Memory Bank are the other
later commits. The module of the runs is the published package, not a build: the
controller downloads it from the PowerShell Gallery with `-Version`.

## Method

Four chains ran on the Hyper-V host, one at a time. A chain is a PowerShell 7
script that runs each stage of the kit as its own Windows PowerShell 5.1
process with a clean module path. The chains d1 and a1 restored the saved
machines that they needed (`Start-LabMachines.ps1`, domain controllers first;
d2 reused the machines of d1). The chains d1, d2, and a1 checked the identity of
the published version (`Test-PublishedRelease.ps1`: the tag, the CI run, the
Gallery hash, and the GitHub zip), froze the files of the kit commit in a
worktree, and checked the readiness of the machines
(`Test-MatrixReadiness.ps1`). The chain a2 used the worktree and the extracted
package of a1, so it only checked the readiness of the matrix lab. The scripts
of the chains are helpers of this run, in the session files and listed in the
evidence (`Chain-Extended.ps1`, `Run-LiveDetect.ps1`, `Chain-SuiteOnly2.ps1`,
`Compare-Detect.ps1`); they aren't part of the kit. The controller, the live
tests, and the kit scripts are those of the commit.

| Chain | What it ran | UTC |
| --- | --- | --- |
| d1 | detection on rc9: the controller in the first lab, both editions, then `-RemoveFixture` and the check of the end state | 2026-11-10 22:57 to 23:21 |
| d2 | detection on rc8: the same kit and lab, against the published rc8 | 23:21 to 23:44 |
| a1 | acceptance of rc9: the identity check, the restore of both labs, the readiness checks, the controller in the three cells (23:58 to 00:23) and in the first lab, both editions (00:23 to 00:44), and the check of both labs, CLEAN (00:45) | 23:50 to 00:45 |
| a2 | acceptance of rc9: the module's suite on six machines, after a restart of `OSWin11E` for a new hour and a check of its secure channel; then the check of the matrix lab, CLEAN (01:21) | 00:47 to 01:21 |

- **Detection.** The controller ran once per version and edition with
  `-Version`, so the package is the published one, downloaded from the
  PowerShell Gallery and checked against the SHA-512 that the Gallery publishes.
  `Validate-LabResults.ps1` checked every role from the result files, with
  `-Expect Candidate` for rc9 and `-Expect Baseline` for rc8, whose failures are
  expected. `Compare-Detect.ps1` joined the two runs by edition, role, and the
  full test name, and classified every pair: passed on both, fails on rc8 and
  passes on rc9, skipped on both, or a problem (a test that passes on rc8 and
  fails on rc9, or fails on both, or is missing on one side). The two runs have
  no problem row.
- **Acceptance.** The chain a1 (`Chain-Extended.ps1`, stages `machines`,
  `identity`, `readiness`, `matrix`, `first-lab`, and `verify`) restored both
  labs, checked the identity, started `OSWin11E`, ran the controller in the
  three cells (`Run-MatrixSequence.ps1 -Version`: one cell per file server, with
  the client `OSWin11E`), then in the first lab
  (`Run-LiveAcceptancePublished.ps1`: both editions, validation, removal of the
  fixture, and the check of the end state), and checked both labs
  (`Verify-Labs.ps1`). The chain a2 (`Chain-SuiteOnly2.ps1`) ran the unit suite
  of the kit commit, with its 52 new unit cases, against the extracted
  published module on `OSWin11E`, `OSFile19`, `OSFile22`, `OSFile25`, `OSWin11`
  (with its local account), and the host: four configurations per machine
  (Windows PowerShell 5.1 and PowerShell 7, elevated and as a basic user;
  `Run-MatrixLocalSuite.ps1`). `OSWin11E` shuts itself down an hour after each
  start, the six suites of the earlier record took 33 minutes together, and the
  cells took 25 minutes, so a2 stopped the client, which had
  about five minutes left, started it again for a new hour, waited four
  minutes, and let the lab account open a session on it
  (`Repair-ClientChannel2.ps1`, which repairs the secure channel only when that
  session fails; it passed at the first try, 4.2 minutes after the start). The
  six suites then started 75 seconds apart, because AutomatedLab imports one lab
  at a time. After the suites, a short call of `Chain-Extended.ps1` with
  `-Stage verify-matrix` checked the matrix lab (`Test-MatrixCleanup.ps1 -Mode
  Verify` for the three file servers and `OSWin11E`, and `Verify-Client.ps1` for
  `OSWin11`).
- **No checkpoint.** The procedure in the README takes a checkpoint of the
  machines before a run. These runs took none; the end state of every run was
  verified instead.

### Deviations

- The detection of rc8 and rc9 ran as two chains with the same kit commit,
  not as one chain with `-Version 5.0.0-rc8, 5.0.0-rc9`. Each chain has its own
  evidence folder and logged the same controller and live-test blobs.
- The log of d1 labels the validation of rc9 `Baseline`, not `Candidate`: a
  variable of the chain script (`$detectVersions`) overwrote its own
  `[string] $DetectVersions` parameter, because PowerShell variables ignore
  case, and the candidate became the first character of the version string. The
  result files are unaffected. The same result folders were validated again with
  `-Expect Candidate`, right after the run (the files `d1-candidate-*` in
  `validate-candidate`) and again on 2026-11-11 for the record
  (`revalidation-2026-11-11-*.log`, which print `LIVE_RESULT_VERIFIED
  (Candidate)` for both editions). The script is fixed in the evidence.
- The acceptance ran as two chains, not one, and the suites ran after the cells
  and the first lab; in the earlier record, the suites and the first lab ran
  before the cells. The reason is the hour of `OSWin11E` (see "Acceptance"
  above). The chain a2 used the worktree and the extracted package of a1 and
  didn't check the identity again; its log has the commit of the worktree and
  the SHA-256 of the DLL, which equal those of a1.
- The check of the matrix lab after the suites is a separate call of the chain
  script (`-Tag a2 -SidTag a1 -Stage verify-matrix`; log
  `chain-published-a2.log`). The parameter `-SidTag` was added to the script for
  it, because the first version looked for the SIDs of the fixture under the tag
  of the call, and the fixtures of the cells belong to a1.

## Results

### Detection: the published rc8 against the published rc9

First lab (`WindowsAccessControlLab`), both editions, the same kit: the
controller ran for rc9 from 23:01 to 23:20 UTC (d1) and for rc8 from 23:24 to
23:42 UTC (d2). The counts are the same in both editions
([Counts.csv](Acceptance-2026-11-10-published-rc9-case-11-Counts.csv)):

| Role | rc9, passed / failed / skipped | rc8, passed / failed / skipped |
| --- | --- | --- |
| Delegate | 122 / 0 / 0 | 94 / 28 / 0 |
| ServerAdmin | 67 / 0 / 0 | 49 / 18 / 0 |
| Admin | 95 / 0 / 0 | 77 / 18 / 0 |
| Server | 152 / 0 / 1 | 137 / 15 / 1 |

That is 436 passed, 0 failed, and 1 skipped per edition for rc9 (the 245 passed
and 1 skipped of the earlier records and the 191 tests of case 11), and 357
passed, 79 failed, and 1 skipped for rc8. The skipped test is the test of the
module version in the Server role, which runs without the module. The
comparison pairs 437 tests per edition:

| Class | Tests per edition |
| --- | ---: |
| Cases 1 to 10: passed on both (245) or skipped on both (1) | 246 |
| Case 11 tests that pass on both | 112 |
| Case 11 tests that fail on rc8 and pass on rc9 | 79 |
| Problem rows | 0 |

The 79 are tests that pin an rc9 change, and none of them fails for another
reason than the one in the table above. The first line of the message of rc8
for each of them is in
[Detection.csv](Acceptance-2026-11-10-published-rc9-case-11-Detection.csv)
(158 rows, 79 per edition):

| Group | Per edition | What rc8 wrote |
| --- | ---: | --- |
| Piped rows of the access cmdlets | 3 | no `InvalidParameterValue` error (1); the error ID `ParameterBindingFailed,NTFSSecurity.AddAccess` instead of `InvalidParameterValue,*` (2) |
| Piped rows of the audit cmdlets | 4 | no `InvalidParameterValue` error |
| Sets of security descriptors | 2 | the exception `Argument cannot be zero. Parameter name: accessMask` |
| Later command at `RestoreOwnerError` | 7 | `Expected exactly 'case 11 later command', but got $null.` |
| Filter, literal results | 21 | other names than the expected ones (7 patterns in each of the 3 roles) |
| Filter against `Get-ChildItem` of Windows PowerShell 5.1 | 27 | other names than Windows PowerShell 5.1 returns (9 patterns in each of the 3 roles) |
| State | 15 | an `Allow` entry for `Denyy` and a `Deny` entry for the list, the audit flags `Success, Failure` for a misspelled flag, the unchanged second descriptor, and `Expected $false, but got $true` for the changed next folder |

The 9 patterns of the comparison are `*.`, `*.?`, `*.??`, `*.*.*`, `Report.*`,
`Report.`, `Rep*.`, `a?`, and `a.*`; the 7 literal results are `*.??`,
`Report.*` (in three spellings of the case), `Report.`, `*.`, and the empty
filter. The other 7 patterns of the comparison (`*`, `*.*`, `?`, `*a*`,
`*e*e*`, `*.txt`, and `UPPER*`), the other 3 literal results (`?`, `*.txt`, and
`LONGFI~1*`), and the 3 documented differences pass on both.

The end state of both runs was checked after the removal of the fixture
(`Test-MatrixCleanup.ps1`): CLEAN for d1 at 23:21 UTC and for d2 at 23:43 UTC,
for the four domains and both machines.

### First lab with case 11, acceptance run

`WindowsAccessControlLab` again, as the last stage of the chain a1: one
controller run per edition (`live-a1`), Windows PowerShell from 00:24 to 00:34
UTC and PowerShell 7 from 00:34 to 00:42 UTC. The counts are the same in both
editions and equal to those of the detection run of rc9
([FirstLab.csv](Acceptance-2026-11-10-published-rc9-case-11-FirstLab.csv)):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 122 / 0 / 0 |
| ServerAdmin | 67 / 0 / 0 |
| Admin | 95 / 0 / 0 |
| Server | 152 / 0 / 1 |

That is 436 passed, 0 failed, and 1 skipped per edition (the 245 passed and 1
skipped of cases 1 to 10 and the 191 tests of case 11). Case 9, which needs the
trusts of this lab, ran. The skipped test is the test of the module version in
the Server role. `Validate-LabResults.ps1` printed `LIVE_RESULT_VERIFIED
(Candidate)` for both editions. After the removal of the fixture, the check of
the end state (`Test-MatrixCleanup.ps1 -Mode Verify`) said CLEAN at 00:43 UTC:
no organizational unit, account, or probe account in the four domains, and no
share, folder, local group, membership, profile, scheduled task, or stage item
of the fixture on `F1AFile1` and `F1AFile2`.

### Live controller in the matrix

The Windows 11 client `OSWin11E` with each file server, one sequence (`a1`),
23:58 to 00:23 UTC; the client had been started at 23:54 UTC. Every role was
checked from the result files, and `Validate-LabResults.ps1` printed
`LIVE_RESULT_VERIFIED (Candidate)` for each cell. The counts are the same in
both editions and in all three cells
([Cells.csv](Acceptance-2026-11-10-published-rc9-case-11-Cells.csv); its `Run`
column holds the label of the sequence):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 122 / 0 / 0 |
| ServerAdmin | 67 / 0 / 0 |
| Admin | 82 / 0 / 1 |
| Server | 149 / 0 / 1 |

That is 420 passed, 0 failed, and 2 skipped per edition and cell (the 229
passed and 2 skipped of the earlier record and the 191 tests of case 11), and
2,520 passed, 0 failed, 12 skipped for the three cells. The skipped tests are
those of the earlier records: case 9 (the matrix lab has no foreign domain) and
the test of the module version in the Server role. No test of case 11 was
skipped, so the 8.3 test ran on all three file servers, and they create short
names.

| File server | Cell (UTC) | Controller (UTC) | End-state check |
| --- | --- | --- | --- |
| OSFile19 (Windows Server 2019 10.0.17763.1217) | 23:58:02 to 00:05:35 | 23:58:35 to 00:04:26 | CLEAN |
| OSFile22 (Windows Server 2022 10.0.20348.4773) | 00:05:35 to 00:13:15 | 00:06:03 to 00:12:14 | CLEAN |
| OSFile25 (Windows Server 2025 10.0.26100.32690) | 00:13:15 to 00:23:30 | 00:13:44 to 00:22:28 | CLEAN |

The client is Windows 11 Enterprise Evaluation 10.0.22621.525. The controller
and the live tests of the cells are the blobs of the kit commit (the sequence
log has both). The independent check of each cell (`Test-MatrixCleanup.ps1
-Mode Verify` with the SIDs of that cell) said CLEAN right after the cell:
no organizational unit, account, share, folder, local group, membership, or
profile of the fixture, and none of the residue that the check counts.

### The module's own suite

Passed / failed / skipped, chain a2, 00:54 to 01:15 UTC (the runs of each
machine are in
[LocalSuite.csv](Acceptance-2026-11-10-published-rc9-case-11-LocalSuite.csv)).
Every configuration has 1,911 cases on the machines of the domain and on
`OSWin11`, and 1,910 on the host, which has no DNS domain, so the test of the
fully qualified name of this computer doesn't exist there. The earlier record
had 1,859 and 1,858; the difference is the 52 unit cases of this branch.

| Machine | Elevated, Windows PowerShell | Elevated, PowerShell 7 | Basic user, Windows PowerShell | Basic user, PowerShell 7 |
| --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSFile22 (Server 2022) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSFile25 (Server 2025) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSWin11E (Windows 11 22H2) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSWin11 (Windows 11 26H1) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| Host (reference) | 1,890 / 0 / 20 | 1,888 / 0 / 22 | 1,558 / 0 / 352 | 1,556 / 0 / 354 |

In all 20 comparisons with the host, the skipped tests are the same, name for
name, as multisets (`Export-MatrixResults.ps1` found no difference). No run has
a failed test, and every run's result is Passed. The operating system builds
are those of the readiness check at 00:49 UTC (Windows Server 2019 17763.1217,
2022 20348.4773, and 2025 26100.32690 on the domain controller and the file
servers) and of the suite logs (Windows 11 22H2 22621.525 and 26H1 28000.1836).
The host is Windows
Server 2025 26100.33650 with PowerShell 7.6.9; the virtual machines have
PowerShell 7.6.3. The suites took 8 minutes on the host and 11 to 17 minutes on
the virtual machines (`OSWin11E` 11, `OSFile25` 17); the six suites of the
earlier record took 33 minutes together.

Right after the suites, the check of the matrix lab (01:21 UTC) found nothing of
the fixture on the three file servers and on `OSWin11E`, and the check of
`OSWin11` with its local account found it clean: CLEAN.

## Limits and open items

- This is the acceptance of one published binary with the kit of one commit.
  A changed binary needs the same cells again, and results of different
  binaries don't combine into one matrix. A stable 5.0.0 is a new build,
  because its manifest has no `Prerelease` value, so the identity of the tested
  bytes doesn't carry over to it; the release procedure
  (`Docs/Contributing/05-Releasing.md`) accepts the last prerelease instead,
  which is the maintainer's decision. The stable change is meant to touch only
  the label of the manifest, the CHANGELOG, and the list of published versions
  of the repository tests; after the release, `git diff --stat 5.0.0-rc9 5.0.0
  -- NTFSSecurity Security2 PrivilegeControl ProcessPrivileges Log` should list
  only `NTFSSecurity/NTFSSecurity.psd1`.
- Case 11 doesn't pin the rc9 changes that don't depend on where the item is,
  and ten of the 17 handlers that retry as the owner can't be driven into
  `RestoreOwnerError` by the lab; the sections "What has no live test" and the
  coverage report give the reasons. No SMB trigger was found or built for the
  new `ReadSecurityError` of `Get-NTFSOrphanedAccess`.
- The live runs aren't instrumented for coverage. The coverage report measures
  the unit suite; Handoff 5 measured that the live suite adds 9 sequence points
  at rc7, all of the effective-access code.
- The first lab has only Windows Server 2025 and runs case 9, which needs the
  trusts of that lab; the cells have Windows Server 2019, 2022, and 2025 file
  servers and the Windows 11 22H2 evaluation client, and skip case 9. Windows
  11 26H1 has no live cell: its secure channel to the Windows Server 2025
  domain controller of the matrix lab fails, so it runs the suite only.
- The file servers are Windows. A server of another kind is the subject of
  Decision 23 (issue #34) and wasn't tested; the CHANGELOG carries the caveat
  that the maintainer chose on 2026-11-10. Server Core, ARM64, localized
  operating systems, and file servers that aren't Windows are outside the
  audience of the tool and don't need tests (maintainer, 2026-10-11,
  Decision 25).
- The matrix and its decision (Decision 24) are the maintainer's. This record
  and its parent accept the published rc9 on that matrix; whether the gate is
  closed is the maintainer's decision.
- Three tests of the filter compare with `Get-ChildItem` of Windows PowerShell
  5.1 in a child process as the account of the run. The answers depend on the
  file server: the 8.3 test skips when the server creates no short name (it ran
  on every server of these runs, because no test of case 11 was skipped).
- The scripts of the chains are helpers in the session files, not part of the
  kit. The first draft of `Chain-Extended.ps1` had the variable error described
  under the deviations; it is fixed there, and no later chain was affected.
- At the end of the runs, `OSWin11E` shuts itself down an hour after its last
  start, and the other machines of both labs were saved. Neither lab has a
  fixture.

## Evidence

The evidence is outside Git, in the session folder
`C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files`
(`E` below). `E\qg-unknowns\ext-a1\evidence-manifest.csv` lists the files of the
four chains, of the probes of the known limits, and of the helper scripts that
the chains ran, each with its size and SHA-256. It leaves out the checkouts of
the kit (the folders `worktree`), which Git reproduces.

| Path | Content |
| --- | --- |
| `E\qg-unknowns\ext-d1` | detection on rc9: the chain log, the identity files, `live-detect-d1` (the result files of every role and edition, the validation logs, the cleanup logs), and `validate-candidate` (the strict re-validation) |
| `E\qg-unknowns\ext-d2` | detection on rc8: the same, and `compare` (`rc8-vs-rc9-comparison.csv` has the 874 pairs with both results and the first line of each failure) |
| `E\qg-unknowns\ext-a1` | the acceptance chain a1 (`chain-published-a1.log`, `live-matrix-a1` with a folder per cell, `live-a1` for the first lab, `verify-a1`), the chain a2 (`chain-suites-a2.log`, `localsuite-a2`, `client-channel-a2.log`), the check of the matrix lab after the suites (`chain-published-a2.log`, `verify-matrix-after-suites-a2.log`, `verify-client-a2.log`), the saves of the machines (`lab-save-First.log`, `lab-save-Matrix.log`), the identity files in `published`, and `tables` |
| `E\qg-unknowns\scripts` | the helpers: `Chain-Extended.ps1`, `Chain-SuiteOnly2.ps1`, `Run-LiveDetect.ps1`, `Compare-Detect.ps1`, `Build-Case11Tables.ps1`, `Build-EvidenceManifest.ps1`, `Save-LabMachines.ps1`, and the scripts of the earlier records (inspect them before reuse) |
| `E\rc9-coverage\probes` | the probes of the known limits on the published rc9, in both editions, which back the CHANGELOG: `p-limits-Desktop.log` and `p-limits-Core.log` (the NULL DACL and FAT32, the piped algorithm, the settings of `Get-NTFSAccess` and `Get-ChildItem2`), `p-limits3*` (the five cmdlets that read `GetInheritedFrom`), `p-limits2-filter-published-rc9.log` (the case folding of `-Filter`), and the `p-limits2*` outputs with their driver logs and exit codes (the collection that contains itself) |

The five tables of this record are in this folder:
[Detection](Acceptance-2026-11-10-published-rc9-case-11-Detection.csv),
[Counts](Acceptance-2026-11-10-published-rc9-case-11-Counts.csv),
[Cells](Acceptance-2026-11-10-published-rc9-case-11-Cells.csv),
[FirstLab](Acceptance-2026-11-10-published-rc9-case-11-FirstLab.csv), and
[LocalSuite](Acceptance-2026-11-10-published-rc9-case-11-LocalSuite.csv).
