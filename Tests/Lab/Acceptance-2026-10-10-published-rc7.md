# Acceptance of the published 5.0.0-rc7, 2026-10-10

Live and local acceptance of the exact prerelease that the PowerShell Gallery
has, in the operating-system matrix and in the first lab (stage D of the 5.0.0
quality gate, Decisions 21 and 24). The
[record of the matrix](Acceptance-2026-10-10-os-matrix.md) tested local builds
with `-ModulePath` and said that the acceptance of a release is the run with
`-Version` of the published prerelease. This record doesn't repeat the machines,
the defects, or the method of that record; it adds what differs when the
package comes from the Gallery. It isn't a claim that the quality gate is
complete (see the limits at the end).

## Result

- The published 5.0.0-rc7 passed every stage. The identity check (tag, CI run,
  Gallery hash, GitHub zip) passed before the runs. The live controller passed
  in the three cells of the matrix, both editions, every role: 1,374 passed, 0
  failed, 12 skipped, and the independent end-state check of every cell said
  CLEAN. The module's own suite passed in all 24 runs (six machine classes, two
  editions, elevated and as a basic user), and every skipped test is also
  skipped on the host. The live controller passed in the first lab, where case 9
  runs: 245 passed, 0 failed, 1 skipped in each edition, and the removal of the
  fixture was verified in four domains and on both machines.
- Every number equals the one of the final local candidate `fdd7a8b` in the
  record of the matrix: 1,374 / 0 / 12 in the cells, 245 / 0 / 1 per edition in
  the first lab, and the same counts in all 24 suite runs. The published package
  behaves like the candidate that was tested before it.
- The failures of the effective-access tests of the Admin role in the Windows
  Server 2022 cell, which the earlier record traced to state that outlives a
  re-created account name, did not recur: the controller names that account anew
  for every fixture. One sequence of three cells can't show that an effect that
  depends on timing is gone, so this is an observation, not a proof.
- The run changed nothing in the module, the tests, or the kit: it used the
  files of the tag.

## Candidate and artifact identity

`Test-PublishedRelease.ps1 -Version 5.0.0-rc7` ran at 12:33 UTC, before the
runs, and printed `PUBLISHED_IDENTITY_VERIFIED`. It changes nothing on GitHub or
in the Gallery.

| | Published 5.0.0-rc7 |
| --- | --- |
| Tag | `5.0.0-rc7`, commit `fa0701b591098ec6a6fab2ef12fe2c31d7fc7e88`, on `master` |
| CI run of the tag | `38051611526` (started 12:20:44 UTC): Build and test and Release succeeded |
| PowerShell Gallery | published 12:30:57 UTC; the SHA-512 that the Gallery publishes matches the downloaded package |
| GitHub prerelease | published 12:31:09 UTC |
| `NTFSSecurity.5.0.0-rc7.nupkg` SHA-256 | `40922397B7CB307C64DD99960659539AF5C8AD9D2F55C6BF26E8AB434DEC8DCC` |
| `NTFSSecurity.zip` SHA-256 | `9705C8CCFA0FB8FC355E401444044D94BF176729BA84104D2C423C429AC1430B` |
| `NTFSSecurity.dll` SHA-256 | `D3B7CBE362C37D1016559669CB2EFF5034A6945CA1B03DDB49F1361363D203A7` |
| Manifest | `5.0.0` with `Prerelease = 'rc7'` |

The 11 module files of the nupkg and of the zip are byte for byte equal
([the hashes](Acceptance-2026-10-10-published-rc7-ModuleFiles.csv)). The
controller checks the SHA-512 that the Gallery publishes before it runs a
package, and it kept the package that it downloaded in each of its four runs
(the three cells and the first lab): all four nupkg files and all four DLLs
equal the values above. The suites staged the extracted zip, and their logs
record the same DLL hash. The build isn't byte-reproducible, so these hashes
belong to this one build (see the record of the matrix).

## Method

The method of the record of the matrix applies. What differs:

- **Frozen kit.** The kit, the controller, and the live tests are the files of
  the tag, in an isolated worktree, so that no change of the working tree could
  affect a run in progress. The live tests are the Git blob
  `efe36e5073b9b10742ca7de242ddcbe90d8eda62`, the one of every earlier run of
  the final candidate. The controller is the blob
  `635bf162421b4df4efc76d5677212e8782e8bf77`; it differs from the controllers of
  the runs `rc7l` and `fl1` of the earlier record in comments only (10 and 2
  lines).
- **Order.** The evaluation client `OSWin11E` shuts itself down an hour after
  its start, which was 14:25:49 UTC, so one detached driver ran the stages in
  this order: the three cells of the matrix, the module's suite on six machine
  classes, the check of what the suites left in the matrix lab, and the first
  lab. The first lab doesn't need the client. The driver only calls the scripts
  of the kit; its text is in the local evidence.
- **Live controller.** `Run-MatrixSequence.ps1 -Version 5.0.0-rc7 -FileServer
  OSFile19,OSFile22,OSFile25`, with the client `OSWin11E`: the readiness of
  every machine, the controller in both editions, `Validate-LabResults.ps1` for
  every role from the result files (`-Expect Candidate`), a snapshot of the
  fixture SIDs, `-RemoveFixture`, and `Test-MatrixCleanup.ps1`. In the first lab
  the same stages ran with the foreign domain controllers of case 9.
- **Suite.** `Run-MatrixLocalSuite.ps1 -ModulePath` with the extracted zip,
  `-Mode Elevated,Basic`, both editions, on OSFile19, OSFile22, OSFile25,
  OSWin11E, OSWin11 (with the local installation account), and the host as the
  reference. The processes started 75 seconds apart, because AutomatedLab
  imports one lab at a time.
- **No checkpoint.** The procedure in the README takes a checkpoint of the
  machines before a run. This run took none: the earlier checkpoints report the
  type Standard and weren't touched, and the end state of every cell was
  verified instead.

## Results

### Live controller in the matrix

The Windows 11 client `OSWin11E` with each file server, one sequence
(`g3-m`), 14:29 to 14:52 UTC. Every role was checked from the result files, and
`Validate-LabResults.ps1` printed `LIVE_RESULT_VERIFIED (Candidate)` for each
cell. The counts are the same in both editions and in all three cells
([Cells.csv](Acceptance-2026-10-10-published-rc7-Cells.csv)):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 69 / 0 / 0 |
| ServerAdmin | 36 / 0 / 0 |
| Admin | 51 / 0 / 1 |
| Server | 73 / 0 / 1 |

That is 229 passed, 0 failed, and 2 skipped per edition and cell, and 1,374
passed, 0 failed, 12 skipped for the three cells. The skipped tests are those
of the earlier record: case 9 (the matrix lab has no foreign domain) and the
test of the module version in the Server role (that role runs without the
module).

| File server | Cell | Controller | End-state check |
| --- | --- | --- | --- |
| OSFile19 (Windows Server 2019) | 14:29:11 to 14:36:01 | 14:29:49 to 14:34:56 | CLEAN |
| OSFile22 (Windows Server 2022) | 14:36:01 to 14:42:26 | 14:36:29 to 14:41:27 | CLEAN |
| OSFile25 (Windows Server 2025) | 14:42:26 to 14:51:59 | 14:42:53 to 14:50:58 | CLEAN |

### First lab (case 9)

`WindowsAccessControlLab`, both editions, 15:12 to 15:28 UTC: the domain
controller `F1ADC1`, the file server `F1AFile2`, and the client `F1AFile1`
(domain `a.forest1.net`), with the foreign domain controllers `F1BDC1`,
`F2DC1`, and `F3DC1`. `Validate-LabResults.ps1` printed
`LIVE_RESULT_VERIFIED (Candidate)`. The counts are the same in both editions
([FirstLab.csv](Acceptance-2026-10-10-published-rc7-FirstLab.csv)):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 69 / 0 / 0 |
| ServerAdmin | 36 / 0 / 0 |
| Admin | 64 / 0 / 0 |
| Server | 76 / 0 / 1 |

That is 245 passed, 0 failed, and 1 skipped per edition; the skipped test is
the test of the module version in the Server role. The fixture was removed with
`-RemoveFixture`, and the independent check (10 recorded SIDs: the accounts of
the lab domain and `NtfsLiveForeign` in each of the three foreign domains)
found the four domains and both machines clean: no organizational unit,
account, share, folder, local group, membership, or profile of the fixture, and
none of the residue that the check counts. Its verdict was CLEAN (15:30 UTC).

### The module's own suite

Passed / failed / skipped. Every configuration has 1,011 cases on the machines
of the domain and 1,010 on the host, which has no DNS domain
([LocalSuite.csv](Acceptance-2026-10-10-published-rc7-LocalSuite.csv)).

| Machine | Elevated, Windows PowerShell | Elevated, PowerShell 7 | Basic user, Windows PowerShell | Basic user, PowerShell 7 |
| --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSFile22 (Server 2022) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSFile25 (Server 2025) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSWin11E (Windows 11 22H2) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| OSWin11 (Windows 11 26H1) | 994 / 0 / 17 | 992 / 0 / 19 | 782 / 0 / 229 | 780 / 0 / 231 |
| Host (reference) | 993 / 0 / 17 | 991 / 0 / 19 | 781 / 0 / 229 | 779 / 0 / 231 |

In all 20 comparisons with the host, the skipped tests are the same, name for
name, as multisets. No run has a failed test, a failed container, or a test that
didn't run. The operating-system builds and the PowerShell versions are those of
the record of the matrix (the readiness checks and the results of this run show
the same builds); the host has PowerShell 7.6.6, the virtual machines 7.6.3.

After the suites, `Test-MatrixCleanup.ps1 -Mode Verify` checked the domain and
the machines OSFile19, OSFile22, OSFile25, and OSWin11E again (15:11 UTC): CLEAN
at the first check, so no repair was needed.

## Limits and open items

- This is one run of one binary. A changed binary needs the same cells again;
  results of different binaries don't combine into one matrix. A stable 5.0.0 is
  a new build, because its manifest has no `Prerelease` value, so the identity
  of the tested bytes doesn't carry over to it. The release procedure
  (`Docs/Contributing/05-Releasing.md`) accepts the last prerelease instead;
  that is the maintainer's decision, not this record's.
- Case 9 (accounts of other domains and forests) needs trusts that the matrix
  lab doesn't have, so the cells skip it, and it ran only in the first lab, on
  Windows Server 2025. The first lab has no other operating system.
- Windows 11 26H1 has no live cell: its secure channel to the Windows Server
  2025 domain controller of the lab fails, so it runs the suite only. The client
  of the cells is the Windows 11 22H2 evaluation build.
- The file servers are Windows. A server of another kind is the subject of
  Decision 23 (issue #34) and wasn't tested.
- The matrix and its decision (Decision 24) are proposed. This record is the
  acceptance of the published rc7 on that proposed matrix; whether the matrix is
  the right one, and whether the gate is closed, are the maintainer's decisions.
- `Test-MatrixCleanup.ps1` can't reach OSWin11 with the domain account, so the
  end state of that machine isn't independently verified. The suite runner
  removes its own stage and its scheduled tasks, and the other four machines and
  the domain were clean.
- `OSWin11E` shut itself down by itself after the run, as it does an hour after
  every start (it was off at 15:30 UTC), and was left off. The other machines of
  the matrix lab and of the first lab are running, with no fixture in either
  lab.
- The two LOW findings of the security review in the record of the matrix (the
  swallowed initialization exceptions of `GetEffectiveAccess`, and the ACL of
  the staging folders under `C:\`) are unchanged and weren't part of this run.
- The effective-access state that outlives a re-created account name wasn't
  investigated again; one sequence of three cells is no test of it.

## Evidence

The raw logs, result files, the downloaded packages, and the driver are local,
outside Git, in the session files of the run (the folders `gate3-rc7` and
`published-rc7`). `evidence-manifest.csv` in `gate3-rc7` lists the size and the
SHA-256 of 332 files: everything in `gate3-rc7` except itself, and the four
files at the top of `published-rc7` (the packages, the identity result, and the
hashes of the module files). The tables of this record are next to it:

- [the identity of the module files](Acceptance-2026-10-10-published-rc7-ModuleFiles.csv),
- [the controller cells](Acceptance-2026-10-10-published-rc7-Cells.csv),
- [the counts of the first-lab run](Acceptance-2026-10-10-published-rc7-FirstLab.csv),
- [the suite results](Acceptance-2026-10-10-published-rc7-LocalSuite.csv).

The scripts that ran are in [Acceptance](Acceptance); the decision is
`.memory-bank\decisions\0024-os-matrix-lab.md`.
