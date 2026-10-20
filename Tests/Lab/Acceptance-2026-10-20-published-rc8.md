# Acceptance of the published 5.0.0-rc8, 2026-10-20

Live and local acceptance of the exact prerelease that the PowerShell Gallery
has, in the operating-system matrix and in the first lab. It repeats the
[acceptance of the published 5.0.0-rc7](Acceptance-2026-10-10-published-rc7.md)
with the bytes of rc8, which carries the module changes of the coverage work
since rc7 and the fix of the swallowed initialization errors of
`Get-NTFSEffectiveAccess`. This record doesn't repeat the machines, the
defects, or the method of the earlier records; it adds what differs. It isn't a
claim that the quality gate is complete (see the limits at the end).

## Result

- The published 5.0.0-rc8 passed every stage. The identity check (tag, CI run,
  Gallery hash, GitHub zip) passed before the runs. The live controller passed
  in the three cells of the matrix, both editions, every role: 1,374 passed, 0
  failed, 12 skipped, and the independent end-state check of every cell said
  CLEAN. The module's own suite passed in all 24 runs (six machine classes, two
  editions, elevated and as a basic user), and every skipped test is also
  skipped on the host. The live controller passed in the first lab, where case 9
  runs: 245 passed, 0 failed, 1 skipped in each edition, and the independent
  checks found both labs clean after the run and again at the end.
- The live counts equal those of the published rc7: 1,374 / 0 / 12 in the cells
  and 245 / 0 / 1 per edition in the first lab. The live tests and the
  controller are the same Git blobs as in that run, so the cells measure the
  changed module, not changed tests. The module's suite has 1,191 cases per
  configuration on the machines of the domain (rc7: 1,011), because the
  coverage work added tests.
- The changes of the module since rc7 are listed below. The unit suites on six
  machine classes ran their tests; the live tests of
  `Get-NTFSEffectiveAccess -ServerName` (a computer that can't be reached, and
  a computer that refuses the user) passed unchanged in every cell.
- On Windows Server 2019, 2022, and 2025 and on Windows 11 26H1, a computer name
  of 32,718 characters or more fails with error 14 and a shorter one with error
  1722, the boundary that the CHANGELOG names for the new
  `GetEffectiveAccessError` (see "The long name of -ServerName").
- The run changed nothing in the module, the tests, or the kit: it used the
  files of the tag.

## What differs from the published rc7

The tag has 36 commits without merges after `5.0.0-rc7`, most of them tests and
documents. The module changed in nine C# files and in the manifest:

| Change | Files | Commits |
| --- | --- | --- |
| The `AppliesTo` property of a piped object binds for a path, and the scope of one piped object no longer reaches the next | `AddAccess.cs`, `RemoveAccess.cs`, `AddAudit.cs`, `RemoveAudit.cs` | `93ed2c7`, `9783d2a` |
| `Get-ChildItem2` enumerates and filters without the culture of the thread (the filter missed files under `tr-TR`) | `GetChildItem2.cs` | `0028ccd`, `fbe0289`, `8a625c8` |
| An identity compares with a name without the culture of the thread | `IdentityReference2.cs` | `419cfb3` |
| `Get-NTFSEffectiveAccess` writes a `GetEffectiveAccessError` when Windows refuses to start the authorization manager, and warns that the result is based on this computer only when it calculated one | `GetEffectiveAccess.cs`, `Lib.cs` | `25fe775` |
| The prerelease label | `NTFSSecurity.psd1` | `e2e9324` |

No changed line writes or selects a section (owner, group, DACL, or SACL) of a
security descriptor: the first three rows change how a parameter or a name is
read, and the fourth changes only the read of the effective access.

## Candidate and artifact identity

`Test-PublishedRelease.ps1 -Version 5.0.0-rc8` ran at 10:42 UTC, before the
runs, and printed `PUBLISHED_IDENTITY_VERIFIED`. It changes nothing on GitHub or
in the Gallery.

| | Published 5.0.0-rc8 |
| --- | --- |
| Tag | `5.0.0-rc8`, commit `c71919700c3fc48ac910f86f94f59ab2f5731add`, on `master` (the merge of #127) |
| CI run of the tag | `39408140862` (started 10:28:05 UTC): Build and test and Release succeeded |
| PowerShell Gallery | published 10:40:58 UTC; the SHA-512 that the Gallery publishes matches the downloaded package |
| GitHub prerelease | published 10:41:07 UTC |
| `NTFSSecurity.5.0.0-rc8.nupkg` SHA-256 | `EA90E16F2152016E97BFB3D2413D29F8944704E9D4FBD5101D0A263841BC0510` |
| `NTFSSecurity.zip` SHA-256 | `288152E20F8CFB1B029BAC055345339970C65BD57C8BA814C2616C32D9F812BC` |
| `NTFSSecurity.dll` SHA-256 | `D8CB4015BF25379C77A645F82EEECA54F86219F228A5029E32E4D52FBD016E79` |
| Manifest | `5.0.0` with `Prerelease = 'rc8'` |

The 11 module files of the nupkg and of the zip are byte for byte equal
([the hashes](Acceptance-2026-10-20-published-rc8-ModuleFiles.csv)). The
controller checks the SHA-512 that the Gallery publishes before it runs a
package, and it kept the package that it downloaded in each of its five runs
(the three cells and the two editions of the first lab): all five nupkg files
and all five DLLs equal the values above. The suites staged the extracted zip,
and their logs record the same DLL hash on all six machine classes. The build
isn't byte-reproducible, so these hashes belong to this one build.

## Method

The method of the records of the matrix and of the published rc7 applies. What
differs:

- **Frozen kit.** The kit, the controller, and the live tests are the files of
  the tag, in an isolated worktree, so that no change of the working tree could
  affect a run in progress. The live tests are the Git blob
  `efe36e5073b9b10742ca7de242ddcbe90d8eda62` and the controller the blob
  `635bf162421b4df4efc76d5677212e8782e8bf77`, the same as in the acceptance of
  the published rc7.
- **Machines from the saved state.** Every machine of both labs had been saved
  since 2026-10-11 14:17 UTC. A script restored them in waves (the domain
  controllers first, then the other domain controllers and the certification
  authority, then the file servers and clients), and the readiness check of both
  labs passed at its first attempt (10:43 UTC, clock skew 4 to 5 seconds). The
  evaluation client `OSWin11E` started at 10:43:41 UTC, because it shuts itself
  down an hour after each start. After the run, the machines were saved again,
  as they were found.
- **Order.** One detached driver ran the stages in this order: the identity
  check, the readiness of both labs, the three cells of the matrix, the module's
  suite on six machine classes, the check of what the suites left in the matrix
  lab, and the first lab. The driver only calls the scripts of the kit and a few
  helper scripts (see the evidence).
- **Live controller.** `Run-MatrixSequence.ps1 -Version 5.0.0-rc8 -FileServer
  OSFile19,OSFile22,OSFile25`, with the client `OSWin11E`: the readiness of
  every machine, the controller in both editions, `Validate-LabResults.ps1` for
  every role from the result files (`-Expect Candidate`), a snapshot of the
  fixture SIDs, `-RemoveFixture`, and `Test-MatrixCleanup.ps1`. In the first lab
  the same stages ran with the foreign domain controllers of case 9, with
  `-Version` for each edition in its own run.
- **Suite.** `Run-MatrixLocalSuite.ps1 -ModulePath` with the extracted zip,
  `-Mode Elevated,Basic`, both editions, on OSWin11E, OSFile19, OSFile22,
  OSFile25, OSWin11 (with the local installation account), and the host as the
  reference. The processes started 75 seconds apart, because AutomatedLab
  imports one lab at a time.
- **No checkpoint.** The procedure in the README takes a checkpoint of the
  machines before a run. This run took none: the machines were restored from
  their saved state, and the end state of every cell was verified instead.

## Results

### Live controller in the matrix

The Windows 11 client `OSWin11E` with each file server, one sequence (`rc8`),
10:47 to 11:08 UTC. Every role was checked from the result files, and
`Validate-LabResults.ps1` printed `LIVE_RESULT_VERIFIED (Candidate)` for each
cell. The counts are the same in both editions and in all three cells
([Cells.csv](Acceptance-2026-10-20-published-rc8-Cells.csv)):

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
| OSFile19 (Windows Server 2019) | 10:47:42 to 10:53:53 | 10:48:10 to 10:52:54 | CLEAN |
| OSFile22 (Windows Server 2022) | 10:53:53 to 10:59:45 | 10:54:16 to 10:58:54 | CLEAN |
| OSFile25 (Windows Server 2025) | 10:59:45 to 11:08:42 | 11:00:08 to 11:07:51 | CLEAN |

### First lab (case 9)

`WindowsAccessControlLab`, both editions, 11:26 to 11:46 UTC: the domain
controller `F1ADC1`, the file server `F1AFile2`, and the client `F1AFile1`
(domain `a.forest1.net`), with the foreign domain controllers `F1BDC1`,
`F2DC1`, and `F3DC1`. `Validate-LabResults.ps1` printed
`LIVE_RESULT_VERIFIED (Candidate)` for each edition. The counts are the same in
both editions
([FirstLab.csv](Acceptance-2026-10-20-published-rc8-FirstLab.csv)):

| Role | Passed / failed / skipped |
| --- | --- |
| Delegate | 69 / 0 / 0 |
| ServerAdmin | 36 / 0 / 0 |
| Admin | 64 / 0 / 0 |
| Server | 76 / 0 / 1 |

That is 245 passed, 0 failed, and 1 skipped per edition; the skipped test is
the test of the module version in the Server role. The Windows PowerShell run
took 11:27 to 11:36 UTC and the PowerShell 7 run 11:36 to 11:44 UTC. The
fixture was removed with `-RemoveFixture`, and the independent check found the
four domains and both machines clean: no organizational unit, account, share,
folder, local group, membership, or profile of the fixture, and none of the
residue that the check counts. Its verdict was CLEAN (11:45 UTC). The final
read-only check of both labs after the whole run said CLEAN for the matrix lab
(11:46 UTC) and for the first lab (11:46 UTC).

### The module's own suite

Passed / failed / skipped. Every configuration has 1,191 cases on the machines
of the domain and on `OSWin11`, and 1,190 on the host, which has no DNS domain,
so the test of the fully qualified name of this computer doesn't exist there
([LocalSuite.csv](Acceptance-2026-10-20-published-rc8-LocalSuite.csv)).

| Machine | Elevated, Windows PowerShell | Elevated, PowerShell 7 | Basic user, Windows PowerShell | Basic user, PowerShell 7 |
| --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 1,172 / 0 / 19 | 1,170 / 0 / 21 | 907 / 0 / 284 | 905 / 0 / 286 |
| OSFile22 (Server 2022) | 1,172 / 0 / 19 | 1,170 / 0 / 21 | 907 / 0 / 284 | 905 / 0 / 286 |
| OSFile25 (Server 2025) | 1,172 / 0 / 19 | 1,170 / 0 / 21 | 907 / 0 / 284 | 905 / 0 / 286 |
| OSWin11E (Windows 11 22H2) | 1,172 / 0 / 19 | 1,170 / 0 / 21 | 907 / 0 / 284 | 905 / 0 / 286 |
| OSWin11 (Windows 11 26H1) | 1,172 / 0 / 19 | 1,170 / 0 / 21 | 907 / 0 / 284 | 905 / 0 / 286 |
| Host (reference) | 1,171 / 0 / 19 | 1,169 / 0 / 21 | 906 / 0 / 284 | 904 / 0 / 286 |

In all 20 comparisons with the host, the skipped tests are the same, name for
name, as multisets (`Export-MatrixResults.ps1` found no difference). No run has
a failed test, a failed container, or a test that didn't run. The operating
system builds are those of the readiness checks (Windows Server 2019
17763.1217, 2022 20348.4773, and 2025 26100.32690 on the domain controller and
the file servers; Windows 11 22H2 22621.525 and 26H1 28000); the host has
PowerShell 7.6.7, the virtual machines 7.6.3.

After the suites, `Test-MatrixCleanup.ps1 -Mode Verify` checked the domain and
the machines OSFile19, OSFile22, OSFile25, and OSWin11E again (11:26 UTC):
CLEAN at the first check, so no repair was needed. A read-only script checked
`OSWin11` with its local account (11:26 UTC): no scheduled task, stage item,
probe user, profile, share, folder, or live user.

### The long name of -ServerName

The CHANGELOG says that `Get-NTFSEffectiveAccess` now writes a
`GetEffectiveAccessError` for a computer name of 32,718 characters or more,
because Windows refuses to start the authorization manager for it. A probe with
the call and the structure of `Security2\Win32\Lib.cs`
(`AuthzInitializeRemoteResourceManager`), run on the machines of the matrix lab
after the acceptance, shows the same boundary on every one of them:

| Machine | Operating system | 1 to 32,717 characters | 32,718 characters and more (also 32,768 and 70,000) |
| --- | --- | --- | --- |
| OSFile19 | Windows Server 2019 Datacenter 10.0.17763 | 1722 (RPC server unavailable) | 14 |
| OSFile22 | Windows Server 2022 Datacenter 10.0.20348 | 1722 | 14 |
| OSFile25 | Windows Server 2025 Datacenter 10.0.26100 | 1722 | 14 |
| OSWin11 | Windows 11 Pro 10.0.28000 | 1722 | 14 |

The probed lengths were 1, 255, 16,000, 32,717, 32,718, 32,768, and 70,000. On
the host (Windows Server 2025), a bisection in both editions found the same
boundary. Error 1722 keeps the fallback to this computer with its warning, and
error 14 is the new error, so the regression test of the fix, which accepts
either outcome, takes its error branch on each of these systems. `OSWin11E`
was off when the probe ran and wasn't probed.

## Limits and open items

- This is one run of one binary. A changed binary needs the same cells again;
  results of different binaries don't combine into one matrix. A stable 5.0.0
  is a new build, because its manifest has no `Prerelease` value, so the
  identity of the tested bytes doesn't carry over to it. The release procedure
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
- The matrix and its decision (Decision 24) are the maintainer's. This record is
  the acceptance of the published rc8 on that matrix; whether the matrix is the
  right one, and whether the gate is closed, are the maintainer's decisions.
- `Test-MatrixCleanup.ps1` can't reach `OSWin11` with the domain account. The
  read-only script that checked it with the local account is a helper of this
  run (see the evidence), not a script of the kit.
- `OSWin11E` shut itself down by itself after the run, as it does an hour after
  every start (it was off at 11:51 UTC), and was left off. All the other
  machines of both labs were saved again at 11:52 to 11:53 UTC; neither lab has
  a fixture.
- Of the two LOW findings of the security review in the record of the matrix,
  the swallowed initialization exceptions of `GetEffectiveAccess` are fixed in
  this build (#127). The ACL of the staging folders under `C:\` is unchanged and
  wasn't part of this run.
- The effective-access state that outlives a re-created account name wasn't
  investigated again; the three cells of one sequence are no test of it. The
  failures that the earlier record traced to it didn't recur.

## Evidence

The raw logs, result files, the downloaded packages, and the driver are local,
outside Git, in the session files of the run (the folder `rc8-published`).
`evidence-manifest.csv` there lists the size and the SHA-256 of every file
except itself and the worktree of the tag, which holds the files of the commit
that Git has. The helper scripts of the run are in the folder `scripts` next to
it: the driver (`Chain-Published.ps1`), the restore of the machines
(`Start-LabMachines.ps1`), the first-lab run with `-Version`
(`Run-LiveAcceptancePublished.ps1`), the check of `OSWin11`
(`Verify-Client.ps1`), and the exporter of the tables of this record
(`Build-RecordTables.ps1`); the probe of the long name is
`p-authz-init-lab.ps1` in `probes`. The tables of this record are next to it:

- [the identity of the module files](Acceptance-2026-10-20-published-rc8-ModuleFiles.csv),
- [the controller cells](Acceptance-2026-10-20-published-rc8-Cells.csv),
- [the counts of the first-lab run](Acceptance-2026-10-20-published-rc8-FirstLab.csv),
- [the suite results](Acceptance-2026-10-20-published-rc8-LocalSuite.csv).

The scripts of the kit that ran are in [Acceptance](Acceptance); the decision is
`.memory-bank\decisions\0024-os-matrix-lab.md`.
