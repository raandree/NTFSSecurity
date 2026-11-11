# Acceptance of the published 5.0.0-rc9a, 2026-11-11

Live and local acceptance of the exact prerelease that the PowerShell Gallery
has, in the operating-system matrix and in the first lab. 5.0.0-rc9a ships the
code of rc9, built again: the module folders of the tag `5.0.0-rc9a` differ
from those of `5.0.0-rc9` only in the manifest, and the release notes add the
note about #34 and the six known limits (Decision 21, "Another prerelease
before stable"). The stable 5.0.0 is accepted through the last prerelease, and
a new build needs the cells again, so this record repeats the
[acceptance of the published rc9 with case 11](Acceptance-2026-11-10-published-rc9-case-11.md)
with the bytes of rc9a and the kit of its own tag. It doesn't repeat the
method of the earlier records; it adds what differs. It isn't a claim that
the quality gate is complete (see the limits at the end).

## Result

- The published 5.0.0-rc9a passed every stage. The identity check (tag, CI
  run, Gallery hash, GitHub zip) passed before the runs.
- The live controller passed in the three cells of the matrix, both editions,
  every role: 2,520 passed, 0 failed, 12 skipped, 420 / 0 / 2 per edition and
  cell. Every cell was validated from its result files, and its end state was
  CLEAN.
- The live controller passed in the first lab, where case 9 runs: 436 passed,
  0 failed, 1 skipped in each edition (`LIVE_RESULT_VERIFIED`), end state
  CLEAN.
- The module's own suite passed in all 24 runs (six machine classes, two
  editions, elevated and as a basic user), 0 failed: 1,911 cases per
  configuration on the machines of the matrix lab and 1,910 on the host. In
  all 20 comparisons with the host, the skipped tests are the same, name for
  name.
- The checks of both labs after the runs, and of the matrix lab and `OSWin11`
  after the suites, found no residue.
- Every count equals that of the published rc9 with case 11 on 2026-11-10 to
  11: the cells, the first lab, and the suite.
- The run came in one detached driver, after a first attempt that stopped
  before any test (see [Deviations](#deviations)). It changed nothing in the
  module, the tests, or the kit.

## What differs from the published rc9

| | Published 5.0.0-rc9 | Published 5.0.0-rc9a |
| --- | --- | --- |
| Tag | `823c814` | `c135062` (the merge of #135) |
| Module source | | `NTFSSecurity/NTFSSecurity.psd1` only: `Prerelease = 'rc9a'` |
| `NTFSSecurity.dll` SHA-256 | `464CAB36…1198` | `EBA00A67…4BC5`: a new build of the same source |
| Release notes (`[Unreleased]`) | | Adds the note for users of file servers that aren't Windows (#34) and `### Known limits` with six items |
| Kit of the acceptance | `5a92d60` (the branch of #134) | The tag `c135062` |

The tests that ran are those of the acceptance of rc9 with case 11. Between
`5a92d60` and the tag, the live tests differ in one comment (`748b8b1`), and
`Tests/Repository.Tests.ps1` lists `5.0.0-rc9` as published, which the lab
doesn't run.

## Candidate and artifact identity

`Test-PublishedRelease.ps1 -Version 5.0.0-rc9a` verified the identity at
14:57 UTC (run by the maintainer) and again at 16:30 UTC in the chain, before
its runs (`PUBLISHED_IDENTITY_VERIFIED`). It changes nothing on GitHub or in
the Gallery.

| | Published 5.0.0-rc9a |
| --- | --- |
| Tag | `5.0.0-rc9a`, commit `c135062c1c74119d6a2e4e719ab98721254a2ed1`, on `master` |
| CI run of the tag | `43039152538` (started 2026-11-11 14:30:40 UTC): Build and test and Release succeeded |
| PowerShell Gallery | published 2026-11-11 14:42:14 UTC; the SHA-512 that the Gallery publishes matches the downloaded package |
| GitHub prerelease | published 2026-11-11 14:42:22 UTC; the asset digest equals the SHA-256 of the zip |
| `NTFSSecurity.5.0.0-rc9a.nupkg` SHA-256 | `60436BD4636E0C218D6C94D3D081671878372E8B986336F9C007ED245A355BA8` |
| `NTFSSecurity.zip` SHA-256 | `3B72CB20A1C4DA82D4BAC17E61F82AA8351732F6942D84662F482452D8447B9F` |
| `NTFSSecurity.dll` SHA-256 | `EBA00A6738E9B9323F0E113582BCFFF288D152F5788A36F95D6828DC2B444BC5` |
| Manifest | `5.0.0` with `Prerelease = 'rc9a'` |

The 11 module files of the nupkg and of the zip are byte for byte equal
([the hashes](Acceptance-2026-11-11-published-rc9a-ModuleFiles.csv)). The
controller checks the SHA-512 that the Gallery publishes before it runs a
package; the suites ran the extracted zip of the identity check of the chain.

## Method

One detached driver ran the chain scripts of the acceptance of rc9 with case
11, unchanged (their SHA-256 are in its log), in Windows PowerShell 5.1 on the
Hyper-V host, with the files of the tag frozen in a worktree as the kit:

| Step | What ran | UTC |
| --- | --- | --- |
| Prepare | The restore of both labs from Saved, the identity check, the readiness of both labs (first attempt: ok) | 16:29:20 to 16:33:02 |
| Client | `OSWin11E` started; its secure channel judged by a session of the lab account (`Repair-ClientChannel2.ps1`): ok 4.2 minutes after the boot, no repair | 16:33:02 to 16:37:20 |
| Cells | `Run-MatrixSequence.ps1 -Version` for `OSFile19`, `OSFile22`, and `OSFile25`, each with validation, removal of the fixture, and the check of the end state | 16:37:20 to 17:01:22 |
| First lab | The controller with `-Version` per edition, validation, removal of the fixture, check of the end state | 17:01:22 to 17:21:53 |
| Check | The read-only check of both labs | 17:21:53 to 17:23:09 |
| Suites | A fresh hour for `OSWin11E`, the gate of its channel again (ok), and `Run-MatrixLocalSuite.ps1 -ModulePath` on six machines, 75 seconds apart | 17:23:09 to 17:50:06 |
| Check | The matrix lab and `OSWin11` after the suites | 17:50:06 to 17:51:01 |

The chain of the rc9 acceptance with case 11 had no gate for the channel of
the evaluation client before the cells; the driver adds it, with the script
that the suites of that acceptance used. At 17:56 UTC the 18 machines of both
labs were saved again, and `OSWin11E` was shut down.

### Deviations

- A first attempt (16:25:51 UTC) stopped two seconds after its start, before
  any test. `Chain-Extended.ps1` creates the worktree of the kit with git
  under `$ErrorActionPreference = 'Stop'`, and Windows PowerShell 5.1 turns
  the progress line that git writes to stderr ("Preparing worktree (detached
  HEAD c135062)") into a terminating error. The chains of 2026-11-10 met an
  existing worktree. The restore that the attempt had started went on and
  ended at 16:28:55 UTC; the second attempt started at 16:29:20 UTC with the
  worktree created beforehand and a fresh evidence folder. The evidence of
  the first attempt is kept.
- The suites chain logged no exit code for the six suite processes, where the
  chain of 2026-11-10 logged 0. The results come from the summary of each run
  (the NUnit and JSON files), not from that field; the cause wasn't
  investigated.
- `Export-MatrixResults.ps1` first ran with `-ReferenceMachine LOCAL`, which
  matches no machine, because it names a machine after the folder of the
  suites (`s-a2-LOCAL-LOCAL` becomes `a2-LOCAL-LOCAL`), so the comparison of
  the skipped tests was empty. The rerun with `-ReferenceMachine
  a2-LOCAL-LOCAL` compared all 20 runs.
- The host runs a newer build than on 2026-11-10: Windows Server 2025
  26100.33822, after an upgrade of the operating system at 03:28 UTC.

## Results

### Live controller in the matrix

Passed / failed / skipped per edition, the same in both editions and in each
cell; the client is `OSWin11E` (Windows 11 22H2 evaluation)
([Cells.csv](Acceptance-2026-11-11-published-rc9a-Cells.csv)).

| Cell | Delegate | ServerAdmin | Admin | Server | Total |
| --- | --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 122 / 0 / 0 | 67 / 0 / 0 | 82 / 0 / 1 | 149 / 0 / 1 | 420 / 0 / 2 |
| OSFile22 (Server 2022) | 122 / 0 / 0 | 67 / 0 / 0 | 82 / 0 / 1 | 149 / 0 / 1 | 420 / 0 / 2 |
| OSFile25 (Server 2025) | 122 / 0 / 0 | 67 / 0 / 0 | 82 / 0 / 1 | 149 / 0 / 1 | 420 / 0 / 2 |

The skipped tests are those of the earlier records: the module version of the
run in the Server role, and case 9 in the Admin role, which needs the trusts
of the first lab.

### First lab

Passed / failed / skipped per edition
([FirstLab.csv](Acceptance-2026-11-11-published-rc9a-FirstLab.csv)): Delegate
122 / 0 / 0, ServerAdmin 67 / 0 / 0, Admin (with case 9) 95 / 0 / 0, Server
152 / 0 / 1 (the module version of the run), in both editions: 436 / 0 / 1.
Windows PowerShell ran from 17:02 to 17:11 UTC and PowerShell 7 from 17:11 to
17:20 UTC.

### The module's own suite

Passed / failed / skipped, 17:29 to 17:50 UTC. Every configuration has 1,911
cases on the machines of the matrix lab and 1,910 on the host, which has no
DNS domain, so the test of the fully qualified name of this computer doesn't
exist there
([LocalSuite.csv](Acceptance-2026-11-11-published-rc9a-LocalSuite.csv)).

| Machine | Elevated, Windows PowerShell | Elevated, PowerShell 7 | Basic user, Windows PowerShell | Basic user, PowerShell 7 |
| --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSFile22 (Server 2022) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSFile25 (Server 2025) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSWin11E (Windows 11 22H2) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| OSWin11 (Windows 11 26H1) | 1,891 / 0 / 20 | 1,889 / 0 / 22 | 1,559 / 0 / 352 | 1,557 / 0 / 354 |
| Host (reference) | 1,890 / 0 / 20 | 1,888 / 0 / 22 | 1,558 / 0 / 352 | 1,556 / 0 / 354 |

In all 20 comparisons with the host, the skipped tests are the same, name for
name, as multisets (`Export-MatrixResults.ps1` found no difference). The
operating-system builds are those of the earlier records (Windows Server 2019
17763.1217, 2022 20348.4773, and 2025 26100.32690; Windows 11 22H2 22621.525
and 26H1 28000.1836); the virtual machines have PowerShell 7.6.3, and the host
PowerShell 7.6.9.

## Limits and open items

- This is the acceptance of one published binary with the kit of its tag. The
  stable 5.0.0 is a new build again, because its manifest has no
  `Prerelease` value; the release procedure
  (`Docs/Contributing/05-Releasing.md`) accepts the last prerelease instead,
  which is the maintainer's decision. The stable change is meant to touch
  only the label of the manifest, the CHANGELOG, and the list of published
  versions; after the release, `git diff --stat 5.0.0-rc9a 5.0.0 --
  NTFSSecurity Security2 PrivilegeControl ProcessPrivileges Log` should list
  only `NTFSSecurity/NTFSSecurity.psd1`.
- What the lab can't show is unchanged: ten of the 17 handlers that retry as
  the owner, the new `ReadSecurityError` of `Get-NTFSOrphanedAccess`, and the
  changes of rc9 that don't depend on where the item is (the section
  [What has no live test](Acceptance-2026-11-10-published-rc9-case-11.md#what-has-no-live-test)
  of the addendum). The live runs aren't instrumented for coverage.
- Case 9 needs the trusts of the first lab, which has only Windows Server
  2025; Windows 11 26H1 has no live cell (its secure channel to the domain
  controller of the matrix lab fails), so it runs the suite only. The file
  servers are Windows; a server of another kind is the subject of Decision 23
  (issue #34), and the release notes carry its caveat.
- The driver and the chain scripts are helpers in the session files, not part
  of the kit.

## Evidence

The evidence is outside git, in the session folder
`C:\Users\install\.copilot\session-state\f097ed24-a01f-4896-9c61-d1a0208cbdff\files`:

- `rc9a-acceptance-2`: the run of this record: `driver.log` (with the SHA-256
  of every chain script), the chain logs (`chain-published-a1.log`,
  `chain-suites-a2.log`, `chain-published-a2.log`), the identity check
  (`published`, with `Identity-5.0.0-rc9a.json`), the cells
  (`live-matrix-a1`), the first lab (`live-a1`), the suites
  (`localsuite-a2`), the checks (`verify-a1`,
  `verify-matrix-after-suites-a2.log`, `verify-client-a2.log`), the gates of
  the client (`client-channel-a1.log`, `client-channel-a2.log`), and the
  exported tables with the SHA-256 of their 81 input files (`tables`).
- `rc9a-acceptance`: the first attempt, which stopped before any test.
- `scripts`: the driver (`Run-PublishedAcceptance.ps1`) and the builder of the
  four tables of this record (`Build-PublishedRecordTables.ps1`).

The chain scripts are those of the release gate, in
`C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns\scripts`.
