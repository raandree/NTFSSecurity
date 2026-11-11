# Acceptance of the published 5.0.0-rc9, 2026-11-10

Live and local acceptance of the exact prerelease that the PowerShell Gallery
has, in the operating-system matrix and in the first lab. It repeats the
[acceptance of the published 5.0.0-rc8](Acceptance-2026-10-20-published-rc8.md)
with the bytes of rc9, which carries the module changes of Decision 27: the
five piped parameters of the access and audit cmdlets, the fixes of the
library, and the others in the table below. This record doesn't repeat the
machines, the defects, or the method of the earlier records; it adds what
differs. It isn't a claim that the quality gate is complete (see the limits at
the end).

## Result

- The published 5.0.0-rc9 passed every stage. The identity check (tag, CI run,
  Gallery hash, GitHub zip) passed before the runs. The live controller passed
  in the three cells of the matrix, both editions, every role: 1,374 passed, 0
  failed, 12 skipped, and the independent end-state check of every cell said
  CLEAN. The module's own suite passed in all 24 runs (six machine classes, two
  editions, elevated and as a basic user), and every skipped test is also
  skipped on the host. The live controller passed in the first lab, where case
  9 runs: 245 passed, 0 failed, 1 skipped in each edition, and the independent
  checks found both labs clean after the run and again at 16:03 UTC.
- The live counts equal those of the published rc7 and rc8: 1,374 / 0 / 12 in
  the cells and 245 / 0 / 1 per edition in the first lab. The live tests and
  the controller are the same Git blobs as in those runs, so the cells measure
  the changed module, not changed tests. The module's suite has 1,859 cases per
  configuration on the machines of the domain (rc8: 1,191), because the
  tests-only round and the changes of rc9 added tests.
- The run came in four parts, not in one. A planned shutdown of the host
  killed the first attempt after cell 1 of the matrix. In the second attempt
  the suites and the first lab passed, but the evaluation client `OSWin11E`
  lost its secure channel after the cold start, so no cell ran, and a first
  rerun of the matrix failed at the same check. A second rerun, after the
  repair of the channel, ran the three cells and passed. Each table of this
  record comes from one run of its stage; the only stage that ran twice is
  cell 1 (OSFile19), which passed in the interrupted attempt too, with the
  same counts. See [Method](#method) for the times.
- A matrix of valid shapes of the five parameters, run on the extracted
  packages of the published rc8 and rc9 in both editions, differs in nine rows
  of `Add-NTFSAccess` and in none of `Remove-NTFSAccess`. The nine rows are
  lists that rc9 rejects by design (see "Probes of the five parameters").
- The run changed nothing in the module, the tests, or the kit: it used the
  files of the tag.

## What differs from the published rc8

The tag has 48 commits without merges after `5.0.0-rc8` (the merges are #126,
#128, #129, #130, and #131), most of them tests, documents, and the Memory
Bank. The module changed in 32 C# files (two of them new,
`ParameterConversion.cs` and `EnumArgumentCompleters.cs`), the project file,
the help file, and the manifest. The tree of the tag equals the tree of the
validated head `696ac38` of the branch of #131.

| Change | Files | Commits |
| --- | --- | --- |
| The five parameters `-AccessType`, `-AuditFlags`, `-AppliesTo`, `-InheritanceFlags`, and `-PropagationFlags` of `Add-NTFSAccess`, `Remove-NTFSAccess`, `Add-NTFSAudit`, and `Remove-NTFSAudit` have the type `Object` and are converted in the cmdlet. A piped value that can't be converted is an `InvalidParameterValue` error for that object, where the cmdlets silently used the default (a typo for `Deny` created an `Allow` entry); a list for `-AccessType` or `-AppliesTo` and a named `$null` are errors; the completers handle quoted words, wildcards, and Turkish capitals | `AddAccess.cs`, `RemoveAccess.cs`, `AddAudit.cs`, `RemoveAudit.cs`, `ParameterConversion.cs`, `EnumArgumentCompleters.cs` | `abdf212`, `d3ba5a9`, `e75bc15`, `1b8a376`, `e39aeed`, `da41a8e`, `ec58a18`, `ce34395`, `b436423`, `696ac38` |
| With `-SecurityDescriptor`, the same four cmdlets write an error for a descriptor whose change fails and go on with the next one, as they do for a path (they ended the command) | the same four files | `62699ee` |
| The 17 cmdlets that take ownership of an item to retry a denied read or change pass on the exception of a later command in the pipeline instead of reporting it as the error of the item | 17 cmdlet files, from `AddAccess.cs` to `SetSecurityDescriptor.cs` | `62cf026`, `7732fe5` |
| `Get-ChildItem2 -Filter` is matched once, in the cmdlet, with the wildcard rules of `Get-ChildItem -Filter` in Windows PowerShell 5.1; an empty filter returns every item, and a pattern of more than 32,767 characters is a parameter error | `GetChildItem2.cs` | `522fd7f`, `ab2fb87`, `2deec17` |
| The library: the conversion of a `FileSecurity` or a `DirectorySecurity` object keeps the descriptor, and a descriptor without an item can be read; `RemoveFileSystemAccessRuleAll` and `RemoveFileSystemAuditRuleAll` honor the list of accounts; the path overloads of `AddFileSystemAccessRule` and `AddFileSystemAuditRule` write at once; a malformed `EnablePrivileges` setting is one error | `Security2/FileSystem/` (ten files), `BaseCmdlets.cs`, `OtherCmdlets.cs` | `987334e`, `a0a97d9`, `a0362c3`, `b69b21e`, `3f146b8`, `e060c24` |
| `Get-NTFSOrphanedAccess` writes a non-terminating `ReadSecurityError` for an item that it can't read for another reason than a denied access (it wrote a warning) | `GetOrphanedAccess.cs` | `9fde8d1` |
| `-SecurityDescriptor` of `Set-NTFSSecurityDescriptor` is at position 1 (it was at position 2) | `SetSecurityDescriptor.cs` | `37bd42d` |
| The prerelease label | `NTFSSecurity.psd1` | `accf6b8` |

Unlike the changes of rc8, these include code that writes security
descriptors: the path overloads of `AddFileSystemAccessRule` and
`AddFileSystemAuditRule` write at once, and the 17 cmdlets change what happens
when the owner can't be restored. The live tests are unchanged, so the cells
show that no behavior they check broke. They don't exercise the new error
paths; the unit suite does, and it ran in 24 configurations.

## Candidate and artifact identity

`Test-PublishedRelease.ps1 -Version 5.0.0-rc9` printed
`PUBLISHED_IDENTITY_VERIFIED` on 2026-10-22 (at 10:54 UTC, and again at 11:02
UTC in the first attempt) and on 2026-11-10 at 14:27 UTC, in the second
attempt, before its runs. It changes nothing on GitHub or in the Gallery.

| | Published 5.0.0-rc9 |
| --- | --- |
| Tag | `5.0.0-rc9`, commit `823c814908a048e1607816a1041dc63357e01dfe`, on `master` (the merge of #131) |
| CI run of the tag | `39749188259` (started 2026-10-22 08:37:59 UTC): Build and test and Release succeeded |
| PowerShell Gallery | published 2026-10-22 08:50:59 UTC; the SHA-512 that the Gallery publishes matches the downloaded package |
| GitHub prerelease | published 2026-10-22 08:51:19 UTC |
| `NTFSSecurity.5.0.0-rc9.nupkg` SHA-256 | `72CC5E28567BEC564DB052AF34C91F237ECFC9558FA2E981E201E02E16B4F8F3` |
| `NTFSSecurity.zip` SHA-256 | `5A05BC008605D9B4B1EAB074FFC811B460FAF6D3549701D00ABA15D9208ED571` |
| `NTFSSecurity.dll` SHA-256 | `464CAB365AD63CD22208B21012A5B7F0B8B630E819CF300019787A0172791198` |
| Manifest | `5.0.0` with `Prerelease = 'rc9'` |

The 11 module files of the nupkg and of the zip are byte for byte equal
([the hashes](Acceptance-2026-11-10-published-rc9-ModuleFiles.csv)). The
controller checks the SHA-512 that the Gallery publishes before it runs a
package, and it kept the package that it downloaded in each of its six runs
(cell 1 of the first attempt, the three cells of the rerun, and the two
editions of the first lab). All eight nupkg files that the runs kept (those six
and the downloads of the two identity checks) and all ten copies of the DLL
(the extracted packages of the six runs and the extracted nupkg and zip of the
two identity checks) equal the values above. The suites staged the extracted
zip, and their logs record the same DLL hash on all six machine classes. The
build isn't byte-reproducible, so these hashes belong to this one build.

## Method

The method of the records of the matrix and of the published rc8 applies. What
differs:

- **Frozen kit.** The kit, the controller, and the live tests are the files of
  the tag, in an isolated worktree, so that no change of the working tree could
  affect a run in progress. The live tests are the Git blob
  `efe36e5073b9b10742ca7de242ddcbe90d8eda62` and the controller the blob
  `635bf162421b4df4efc76d5677212e8782e8bf77`, the same as in the acceptances of
  the published rc7 and rc8.

The run came in four parts. One detached driver (`Chain-Published.ps1`) ran the
first and the second attempt, and a second driver ran the reruns of the matrix:

| Part | Time (UTC) | What ran | How it ended |
| --- | --- | --- | --- |
| First attempt | 2026-10-22 11:00:36 to 11:14:36 | Start of both labs from the saved state, identity check (11:02), readiness of both labs (11:04), `OSWin11E` started at 11:04:31, cell 1 of the matrix (OSFile19): the controller ended at 11:13:57 with 229 / 0 / 2 per edition and `LIVE_RESULT_VERIFIED`, and its cleanup had just started | A planned shutdown of the host (System event 1074, reason "Other (Planned)") ended every process, and the driver left no end marker. The host stayed off until 2026-11-10 14:16, and the 19 machines of both labs were Off, not saved |
| Second attempt | 2026-11-10 14:26:36 to 15:30:29 | Identity check (14:27); cold start of both labs, ready at the first readiness check (14:31); `OSWin11E` started at 14:31:07; the matrix stage stopped at its readiness check (14:35): `secure channel False` for `OSWin11E`, 4.0 minutes after its start, so no cell ran; the six suites (14:35:43 to 15:08:47); the first lab (15:09:15 to 15:29:30) | The driver ended with its `DONE` marker. The final check at 15:30 found the first lab CLEAN and the matrix lab not, because it still held the fixture of the first attempt |
| First rerun of the matrix | 15:31 to 15:35 | `OSWin11E` restarted (15:31:12), a repair that judged the channel by a session of the local account, and the readiness check again | The check failed at 15:34: the lab account got "Access is denied" from WinRM of `OSWin11E`, so no cell ran |
| Second rerun of the matrix | 15:36:36 to 16:03:09 | Repair of the channel (15:37:07 to 15:37:55), the three cells in one sequence (15:37:57 to 16:01:01), and the checks of both labs and of `OSWin11` (16:01:01 to 16:03:09) | Both labs CLEAN |

- **The channel of OSWin11E.** After a cold start that followed the long
  power-off, the evaluation client refused the lab account: `secure channel
  False` in the readiness check, then "Access is denied" from WinRM.
  `Test-ComputerSecureChannel` in a session of the local account answered True
  at the same time, a stale answer that
  [the record of the matrix](Acceptance-2026-10-10-os-matrix.md) describes. The
  repair that worked was `Test-ComputerSecureChannel -Repair` with the
  credential of the lab account, run from a session of the local account and
  judged by a new session of the lab account. It succeeded at its first
  attempt, 6.7 minutes after the boot. It repairs the lab and says nothing
  about the module; its scripts are in the evidence.
- **The fixture of the first attempt.** The cell of the first attempt had
  created its fixture in the matrix lab (the organizational unit
  `NTFSSecurityLive` with the `NtfsLive*` accounts) and was killed before its
  cleanup. Cell 1 of the rerun started on it: the controller reset the
  password of the existing accounts (the same SIDs, relative identifiers 1552
  to 1558) and created what was missing, and the removal of the fixture at the
  end of the cell deleted the organizational unit. Cells 2 and 3 created their
  own accounts (relative identifiers 1563 to 1569 and 1572 to 1578).
- **Machines.** The host had been off for 19 days, so every machine of both
  labs was Off when the second attempt started. `Start-LabMachines.ps1` started
  them in waves, and both labs passed the readiness check at its first
  attempt, 4.5 minutes after the start. After the rerun, the 18 machines other
  than `OSWin11E` were saved again (16:09 to 16:10 UTC), as the earlier runs
  left them. `OSWin11E` shuts itself down an hour after each start; it was
  running at 16:10 UTC and shuts down about 16:31 UTC. The 22 other virtual
  machines of the host aren't part of these labs and weren't touched.
- **Order.** The suites and the first lab ran before the cells, not after them
  as in the acceptance of rc8. The final checks of both labs, after everything,
  found no residue.
- **Live controller.** `Run-MatrixSequence.ps1 -Version 5.0.0-rc9 -FileServer
  OSFile19,OSFile22,OSFile25` with the client `OSWin11E` (the label `rc9n`):
  the readiness of every machine, the controller in both editions,
  `Validate-LabResults.ps1` for every role from the result files (`-Expect
  Candidate`), a snapshot of the fixture SIDs, `-RemoveFixture`, and
  `Test-MatrixCleanup.ps1`. In the first lab the same stages ran with the
  foreign domain controllers of case 9, with `-Version` for each edition in its
  own run.
- **Suite.** `Run-MatrixLocalSuite.ps1 -ModulePath` with the extracted zip,
  `-Mode Elevated,Basic`, both editions, on OSWin11E, OSFile19, OSFile22,
  OSFile25, OSWin11 (with the local installation account), and the host as the
  reference. The processes started 75 seconds apart, because AutomatedLab
  imports one lab at a time.
- **No checkpoint.** The procedure in the README takes a checkpoint of the
  machines before a run. This run took none; the end state of every cell was
  verified instead.

## Results

### Live controller in the matrix

The Windows 11 client `OSWin11E` with each file server, one sequence (`rc9n`),
15:37 to 16:01 UTC. Every role was checked from the result files, and
`Validate-LabResults.ps1` printed `LIVE_RESULT_VERIFIED (Candidate)` for each
cell. The counts are the same in both editions and in all three cells
([Cells.csv](Acceptance-2026-11-10-published-rc9-Cells.csv); its `Run` column
holds the label of the sequence):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 69 / 0 / 0 |
| ServerAdmin | 36 / 0 / 0 |
| Admin | 51 / 0 / 1 |
| Server | 73 / 0 / 1 |

That is 229 passed, 0 failed, and 2 skipped per edition and cell, and 1,374
passed, 0 failed, 12 skipped for the three cells. The skipped tests are those
of the earlier records: case 9 (the matrix lab has no foreign domain) and the
test of the module version in the Server role (that role runs without the
module).

| File server | Cell | Controller | End-state check |
| --- | --- | --- | --- |
| OSFile19 (Windows Server 2019) | 15:37:57 to 15:44:54 | 15:38:29 to 15:43:45 | CLEAN |
| OSFile22 (Windows Server 2022) | 15:44:54 to 15:51:21 | 15:45:22 to 15:50:23 | CLEAN |
| OSFile25 (Windows Server 2025) | 15:51:21 to 16:01:01 | 15:51:49 to 16:00:02 | CLEAN |

After the third cell, the independent check of the matrix lab
(`Test-MatrixCleanup.ps1 -Mode Verify` with the 7 SIDs of that cell) said CLEAN
at 16:01 UTC for the domain and the machines OSFile19, OSFile22, OSFile25, and
OSWin11E, and again at 16:02 UTC for the domain and the three file servers:
no organizational unit, account, share, folder, local group, membership, or
profile of the fixture, and none of the residue that the check counts. The
read-only check of `OSWin11` with its local account (16:01 UTC) found no
scheduled task, stage item, probe user, profile, share, folder, or live user.

### First lab (case 9)

`WindowsAccessControlLab`, both editions, 15:09 to 15:29 UTC: the domain
controller `F1ADC1`, the file server `F1AFile2`, and the client `F1AFile1`
(domain `a.forest1.net`), with the foreign domain controllers `F1BDC1`,
`F2DC1`, and `F3DC1`. `Validate-LabResults.ps1` printed
`LIVE_RESULT_VERIFIED (Candidate)` for each edition. The counts are the same in
both editions
([FirstLab.csv](Acceptance-2026-11-10-published-rc9-FirstLab.csv)):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 69 / 0 / 0 |
| ServerAdmin | 36 / 0 / 0 |
| Admin | 64 / 0 / 0 |
| Server | 76 / 0 / 1 |

That is 245 passed, 0 failed, and 1 skipped per edition; the skipped test is
the test of the module version in the Server role. The Windows PowerShell run
took 15:09:55 to 15:19:23 UTC and the PowerShell 7 run 15:19:23 to 15:27:36
UTC. The fixture was removed with `-RemoveFixture`, and the independent check
found the four domains and both machines clean (CLEAN at 15:29:30 UTC). The
read-only checks of both labs at the end of the second attempt (15:30 UTC) and
of the second rerun (16:03 UTC) said CLEAN for the first lab again.

### The module's own suite

Passed / failed / skipped, 14:35 to 15:08 UTC. Every configuration has 1,859
cases on the machines of the domain and on `OSWin11`, and 1,858 on the host,
which has no DNS domain, so the test of the fully qualified name of this
computer doesn't exist there
([LocalSuite.csv](Acceptance-2026-11-10-published-rc9-LocalSuite.csv)).

| Machine | Elevated, Windows PowerShell | Elevated, PowerShell 7 | Basic user, Windows PowerShell | Basic user, PowerShell 7 |
| --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 1,839 / 0 / 20 | 1,837 / 0 / 22 | 1,507 / 0 / 352 | 1,505 / 0 / 354 |
| OSFile22 (Server 2022) | 1,839 / 0 / 20 | 1,837 / 0 / 22 | 1,507 / 0 / 352 | 1,505 / 0 / 354 |
| OSFile25 (Server 2025) | 1,839 / 0 / 20 | 1,837 / 0 / 22 | 1,507 / 0 / 352 | 1,505 / 0 / 354 |
| OSWin11E (Windows 11 22H2) | 1,839 / 0 / 20 | 1,837 / 0 / 22 | 1,507 / 0 / 352 | 1,505 / 0 / 354 |
| OSWin11 (Windows 11 26H1) | 1,839 / 0 / 20 | 1,837 / 0 / 22 | 1,507 / 0 / 352 | 1,505 / 0 / 354 |
| Host (reference) | 1,838 / 0 / 20 | 1,836 / 0 / 22 | 1,506 / 0 / 352 | 1,504 / 0 / 354 |

In all 20 comparisons with the host, the skipped tests are the same, name for
name, as multisets (`Export-MatrixResults.ps1` found no difference). No run has
a failed test, and every run's result is Passed. The operating system builds
are those of the readiness checks (Windows Server 2019 17763.1217, 2022
20348.4773, and 2025 26100.32690 on the domain controller and the file
servers; Windows 11 22H2 22621.525 and 26H1 28000.1836). The host is Windows
Server 2025 26100.33650 with PowerShell 7.6.9; the virtual machines have
PowerShell 7.6.3.

Right after the suites, the check of the matrix lab (15:08 UTC) found the
fixture of the first attempt (the organizational unit and the `NtfsLive*`
accounts) and stopped at the missing SID file of a cell, with exit code 1; it
didn't get to the machines. The check of `OSWin11` with its local account
(15:09 UTC) found it clean. The checks after the cells (see above) cover the
residue of the suites and the cells together.

### Probes of the five parameters

On 2026-10-22 (10:55 to 10:59 UTC), before the labs, three probes ran on the
extracted packages of the published rc8 and the published rc9, in both
editions, on the host: a matrix of valid shapes of `Add-NTFSAccess` and of
`Remove-NTFSAccess` (`p-shapes-add`, `p-shapes-remove`), and a probe of lists
and of the flags parameters (`p-lists`). Each probe ran in its own child
process with a timeout, and the outputs of the two builds were compared line
by line. In the first two probes and in the flags rows of the third, every row
gives the same entry or the same error in both builds, except these:

| Probe | Rows per edition | Rows that differ, per edition |
| --- | --- | --- |
| `Add-NTFSAccess`, valid shapes | 438 | 9 |
| `Remove-NTFSAccess`, valid shapes | 214 | 0 |
| Flags parameters | 312 | 18 |

The nine rows of `Add-NTFSAccess` are lists given as a string, in each of the
three ways to bind a value (named, piped, and splatted): `'Allow, Deny'` and
`'Deny,Allow'` for `-AccessType`, and `'ThisFolderOnly,FilesOnly'` for
`-AppliesTo`. rc8 combined the values bit by bit and created a `Deny` entry for
the first two and an `Allow` entry with `ObjectInherit/InheritOnly` for the
third. rc9 reports `InvalidParameterValue` and creates no entry.

The 18 rows of the flags probe are three malformed values (a comma string with
a trailing comma, one with a leading comma, and a `char[]`) for each of
`-InheritanceFlags`, `-PropagationFlags`, and `-AuditFlags`, named and piped.
Named, rc8 stopped with `CannotConvertArgumentNoMessage` and rc9 stops with
`InvalidParameterValue`. Piped, rc8 silently created an entry with the default
of that parameter, and rc9 creates none and writes `InvalidParameterValue`
with the value in the message.

A classification of the output of `p-lists` for the published rc9 checked 220
rows of `-AccessType` and `-AppliesTo`, named and piped, in both editions. A
single value, also in a collection of one element, gives an entry, and a list
of several values (arrays, comma strings, and collections of other kinds)
gives the error "takes one value, not a list" and no entry. No row was wrong.
These are the changes that the CHANGELOG describes. The probe scripts are in
the temporary folder of the review (`C:\Temp\ntfs-rc9\review2-probes-rr-a`);
their output and the runner (`Run-Oracle.ps1`) are in the evidence.

## Limits and open items

- This is one run of one binary, in four parts. A changed binary needs the
  same cells again; results of different binaries don't combine into one
  matrix. A stable 5.0.0 is a new build, because its manifest has no
  `Prerelease` value, so the identity of the tested bytes doesn't carry over
  to it. The release procedure (`Docs/Contributing/05-Releasing.md`) accepts
  the last prerelease instead; that is the maintainer's decision, not this
  record's. The stable change is meant to touch only the label of the
  manifest, the CHANGELOG, and the list of published versions of the
  repository tests. After the release, `git diff --stat 5.0.0-rc9 5.0.0 --
  NTFSSecurity Security2 PrivilegeControl ProcessPrivileges Log` should list
  only `NTFSSecurity/NTFSSecurity.psd1`.
- Case 9 (accounts of other domains and forests) needs trusts that the matrix
  lab doesn't have, so the cells skip it, and it ran only in the first lab, on
  Windows Server 2025. The first lab has no other operating system.
- Windows 11 26H1 has no live cell: its secure channel to the Windows Server
  2025 domain controller of the lab fails, so it runs the suite only. The
  client of the cells is the Windows 11 22H2 evaluation build.
- The file servers are Windows. A server of another kind is the subject of
  Decision 23 (issue #34) and wasn't tested. On 2026-11-10 the maintainer
  decided to release 5.0.0 with a note in the CHANGELOG that names the tested
  file servers (option 2); no tester had reported a result.
- The matrix and its decision (Decision 24) are the maintainer's. This record
  is the acceptance of the published rc9 on that matrix; whether the matrix is
  the right one, and whether the gate is closed, are the maintainer's
  decisions.
- Three things differ from the procedure of the acceptance of rc8: the suites
  ran before the cells, cell 1 started on the accounts of the interrupted
  fixture, and the check of the machines of the matrix lab right after the
  suites stopped at a missing SID file. The residue of the suites was verified
  only by the checks after the cells.
- The effective-access state that outlives a re-created account name wasn't
  investigated again; the three cells of one sequence are no test of it. The
  failures that the earlier record traced to it didn't recur.
- The outputs of the pathological-input probe, which ran on the published
  bytes on 2026-10-22, weren't kept, so this record doesn't rely on them.
- `Test-MatrixCleanup.ps1` can't reach `OSWin11` with the domain account. The
  read-only script that checked it with the local account is a helper of this
  run (see the evidence), not a script of the kit.
- The first repair script for the channel of `OSWin11E` judged success by a
  session of the local account and was wrong; the evidence keeps both versions.
  A detached driver doesn't survive a shutdown of the host, so a run needs the
  host to stay on. Both lessons are in the deployment notes of the Memory Bank.
- At 16:10 UTC, `OSWin11E` was still running (it shuts itself down about 16:31
  UTC), and the other 18 machines of both labs were saved. Neither lab has a
  fixture.
- Of the two LOW findings of the security review in the record of the matrix,
  the ACL of the staging folders under `C:\` is unchanged and wasn't part of
  this run; the other is fixed in rc8 (#127).
- The known limits that Decision 27 lists for rc9 are untouched by this run: a
  collection that holds itself still ends the host through the three flags
  parameters, `Get-FileHash2 -Algorithm` keeps the silent default for a piped
  value that doesn't convert, three settings still read their value with an
  unchecked cast, `PrivilegeEnabler` isn't disposed in some paths, and
  `Get-NTFSEffectiveAccess` fails on a FAT32 volume or for an item with a NULL
  DACL.

## Evidence

The raw logs, result files, the downloaded packages, and the drivers are
local, outside Git, in the session files of the run, in the folder `rc9`:

- `rc9-published` is the first attempt,
- `rc9-published-2` is the second attempt and the reruns of the matrix (the
  stage folders `stage-*`, the sequence `live-matrix-rc9n`, the first lab
  `live-rc9`, the suites `localsuite-rc9`, the checks `verify-rc9`,
  `verify-rc9m`, and `verify-rc9n`, and the exported `tables`),
- `rc9-published-identity` has the packages of the first identity check, and
- `oracle-published-rc9` has the output of the probes of the five parameters.

`evidence-manifest.csv` in that folder lists the size and the SHA-256 of every
file except itself and the worktrees of the tag, which hold the files of the
commit that Git has. The helper scripts of the run are in the folder
`qg-unknowns\scripts` of the same session files: the driver
(`Chain-Published.ps1`), the start of the machines (`Start-LabMachines.ps1`),
the first-lab run with `-Version` (`Run-LiveAcceptancePublished.ps1`), the
checks (`Verify-Client.ps1` and `Verify-Labs.ps1`), the rerun of the matrix
and the repair of the channel (`Rerun-Matrix.ps1`, `Repair-ClientChannel2.ps1`,
and the first version, `Repair-ClientChannel.ps1`), and the exporter of the
tables of this record (`Build-RecordTables2.ps1`). The tables of this record
are next to it:

- [the identity of the module files](Acceptance-2026-11-10-published-rc9-ModuleFiles.csv),
- [the controller cells](Acceptance-2026-11-10-published-rc9-Cells.csv),
- [the counts of the first-lab run](Acceptance-2026-11-10-published-rc9-FirstLab.csv),
- [the suite results](Acceptance-2026-11-10-published-rc9-LocalSuite.csv).

The scripts of the kit that ran are in [Acceptance](Acceptance); the decision
is `.memory-bank\decisions\0024-os-matrix-lab.md`.
