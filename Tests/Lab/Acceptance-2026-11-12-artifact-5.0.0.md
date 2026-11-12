# Acceptance of the 5.0.0 release artifact, 2026-11-12

Live and local acceptance of the exact packages that the PowerShell Gallery
has for 5.0.0, tested before they were published. The CI run of the tag
`5.0.0` built and tested them, and its job Release waited for the approval of
the environment `powershell-gallery` while the lab ran them (Decision 21,
"Live proof of the stable bytes"). The build isn't byte-reproducible, so
without this run no lab test would have seen the bytes that ship. 5.0.0 ships
the code of rc9a: the module folders of the tag `5.0.0` differ from those of
`5.0.0-rc9a` only in the manifest, which has no `Prerelease` value. This
record repeats the
[acceptance of the published rc9a](Acceptance-2026-11-11-published-rc9a.md)
with the artifact and the kit of the tag `5.0.0`; it adds what differs. It
isn't a claim that the quality gate is complete (see the limits at the end).

## Result

- The artifact passed every stage, and the published 5.0.0 is the tested
  artifact, byte for byte: the package that the Gallery serves has the SHA-256
  of the tested nupkg, the SHA-512 that the Gallery publishes matches it, and
  the asset digest of the GitHub release is the SHA-256 of the tested zip.
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
- Every count equals that of the published rc9a, row for row, and the 12
  skipped tests of the cells are the same tests.
- The run came in one detached driver. It changed nothing in the module, the
  tests, or the kit. GitHub lost the CI run of the tag push in an outage, so
  the artifact comes from a manual run on the tag (see
  [Deviations](#deviations)).

## What differs from the published rc9a

| | Published 5.0.0-rc9a | 5.0.0 |
| --- | --- | --- |
| Tag | `c135062` (the merge of #135) | `bff4f61` (the merge of #137) |
| Module source | | `NTFSSecurity/NTFSSecurity.psd1` only: the `Prerelease` value and its comment are removed |
| `NTFSSecurity.dll` SHA-256 | `EBA00A67…4BC5` | `217AA6AC…2234`: a new build of the same source |
| Release notes | `[Unreleased]` | The same text under `## [5.0.0] - 2026-11-11`, and the compare links |
| When the lab ran | After the publication, with the package of the Gallery (`-Version`) | Before the publication, with the artifact of the CI run (`-ModulePath`) |
| CI run | `43039152538`, the push of the tag | `43209324498` (CI #98), a manual run on the tag |
| Kit of the acceptance | The tag `c135062` | The tag `bff4f61` |

Between the two tags, the tests differ only in the record of rc9a and in
`Tests/Repository.Tests.ps1`, which lists `5.0.0-rc9a` as published and which
the lab doesn't run. The controller and the live tests are the same files.

## Candidate and artifact identity

Before the runs, `Prepare-ArtifactAcceptance.ps1` (11:44:55 UTC) checked that
run `43209324498` built the commit of the tag `5.0.0`, that its job "Build and
test" had succeeded, and that its job Release was waiting. It downloaded the
artifact `packages`, compared the module files of the zip and the nupkg, and
read the manifest (`ARTIFACT_IDENTITY_VERIFIED`). After the approval,
`Test-PublishedRelease.ps1 -Version 5.0.0` verified the published version at
13:16:43 UTC (`PUBLISHED_IDENTITY_VERIFIED`, with the fix of this branch; see
[Deviations](#deviations)). Neither script changes anything on GitHub or in
the Gallery.

| | 5.0.0 |
| --- | --- |
| Tag | `5.0.0`, commit `bff4f61260002ab0776ea76ca2ea4f725b160e26`, on `master` |
| CI run | `43209324498` (CI #98, `workflow_dispatch` on the tag, created 2026-11-12 11:27:32 UTC): Build and test succeeded (11:27:39 to 11:43:10 UTC); Release waited for the approval, then succeeded (13:13:29 to 13:13:58 UTC) |
| PowerShell Gallery | published 2026-11-12 13:13:47 UTC, the latest version; its SHA-512 and the SHA-256 of the package that it serves equal those of the tested nupkg |
| GitHub release | published 2026-11-12 13:13:54 UTC, the latest release; the asset digest equals the SHA-256 of the tested zip |
| `NTFSSecurity.5.0.0.nupkg` SHA-256 | `D9F387EF5E625CAF8A5A0F2B72565BFC5E817DCF98EC09AC3DCB514C75E4A596` (299,233 bytes) |
| `NTFSSecurity.zip` SHA-256 | `16B9B39B6A2F8EBA125F0C532598AEA96638D6508591F1B7EA2D65072239B5C5` (297,108 bytes) |
| `NTFSSecurity.dll` SHA-256 | `217AA6AC12916439307EE915868EB00B8EAF455DBFEA22EFB55562325E292234` |
| Manifest | `5.0.0`, no `Prerelease` value |

The 11 module files of the nupkg and of the zip are byte for byte equal
([the hashes](Acceptance-2026-11-12-artifact-5.0.0-ModuleFiles.csv)). Every
stage ran the extracted zip of the artifact: the logs of the cells, of the
first lab, of the six suites, and of the driver name the SHA-256 of its
`NTFSSecurity.dll`, and no log names another.

## Method

One detached driver (`Run-ArtifactAcceptance.ps1`) ran the chain scripts of
the acceptance of rc9a, unchanged (their SHA-256 are in its log), in Windows
PowerShell 5.1 on the Hyper-V host, with the files of the tag frozen in a
worktree as the kit. With `-ModulePath`, the controller labels its runs
`local` (the column Version of
[FirstLab.csv](Acceptance-2026-11-12-artifact-5.0.0-FirstLab.csv)) and checks
no hash of the Gallery; the identity check before the runs takes that place.
All times are 2026-11-12 UTC.

| Step | What ran | UTC |
| --- | --- | --- |
| Build | CI #98 on the tag: the build, the unit suite in four configurations (Windows PowerShell 5.1 and PowerShell 7, elevated and as a basic user), the packages | 11:27:39 to 11:43:10 |
| Artifact | `Prepare-ArtifactAcceptance.ps1`: the identity of the run and of its artifact, the kit of the tag | 11:44:55 |
| Prepare | The restore of both labs from Saved, the readiness of both labs (ok) | 11:45:20 to 11:49:31 |
| Client | `OSWin11E` started; its secure channel judged by a session of the lab account (`Repair-ClientChannel2.ps1`): ok 4.0 minutes after the boot, no repair | 11:49:32 to 11:53:50 |
| Cells | `Run-MatrixSequence.ps1 -ModulePath` for `OSFile19`, `OSFile22`, and `OSFile25`, each with validation, removal of the fixture, and the check of the end state | 11:53:50 to 12:17:50 |
| First lab | The controller with `-ModulePath` per edition, validation, removal of the fixture, check of the end state | 12:17:50 to 12:38:08 |
| Check | The read-only check of both labs | 12:38:08 to 12:39:25 |
| Suites | A fresh hour for `OSWin11E`, the gate of its channel again (ok), and `Run-MatrixLocalSuite.ps1 -ModulePath` on six machines, 75 seconds apart | 12:39:25 to 13:06:24 |
| Check | The matrix lab and `OSWin11` after the suites | 13:06:24 to 13:07:20 |
| Release | The maintainer approved the deployment; the job Release published the artifact | 13:13:29 to 13:13:58 |

At 13:12 UTC the 18 machines of both labs were saved again, and `OSWin11E`
was shut down.

### Deviations

- GitHub lost the CI run of the tag push. The tag was pushed on 2026-11-11 at
  20:44:47 UTC, just before an incident that GitHub reported for Actions,
  Pages, and Copilot from 20:48 to 21:21 UTC, with Actions in major outage.
  Its run (`43097862658`, CI #97) and the runs of the merges of #136 and #137
  (CI #94 to #96) stayed queued without a job, also after GitHub reported its
  backlog as processed. For the run of the tag, a cancel answered that the run
  is completed, a rerun that it is running, and a delete 403. The build came
  from a manual run on the tag the next day (CI #98, started with
  `gh workflow run ci.yml --ref 5.0.0`). Its job Release runs because the ref
  is a tag (`github.ref_type == 'tag'`), and the stuck run of the same
  concurrency group didn't hold it back.
- `Test-PublishedRelease.ps1` of the tag looked only for the push of the tag
  and reported "The latest Release job of the tag did not succeed" for 5.0.0,
  while every other check passed. This branch fixes it: it also takes a
  manual run on the tag, and it reads the job Release of the newest run and
  attempt. The fixed script verified 5.0.0 in PowerShell 7 and in Windows
  PowerShell 5.1, and 5.0.0-rc9a again (the push of its tag).
- The date of `[5.0.0]` in the CHANGELOG is 2026-11-11, the day of the merge;
  the release came a day later, and the job Release warned ("CHANGELOG.md
  dates 5.0.0 2026-11-11, but it is released on 2026-11-12"). The date stays.
- As for rc9a, the suites chain logged no exit code for the six suite
  processes. The results come from the summary of each run (the NUnit and
  JSON files), not from that field.
- The host runs PowerShell 7.6.10 (7.6.9 for rc9a); its Windows build is
  unchanged.

## Results

### Live controller in the matrix

Passed / failed / skipped per edition, the same in both editions and in each
cell; the client is `OSWin11E` (Windows 11 22H2 evaluation)
([Cells.csv](Acceptance-2026-11-12-artifact-5.0.0-Cells.csv)).

| Cell | Delegate | ServerAdmin | Admin | Server | Total |
| --- | --- | --- | --- | --- | --- |
| OSFile19 (Server 2019) | 122 / 0 / 0 | 67 / 0 / 0 | 82 / 0 / 1 | 149 / 0 / 1 | 420 / 0 / 2 |
| OSFile22 (Server 2022) | 122 / 0 / 0 | 67 / 0 / 0 | 82 / 0 / 1 | 149 / 0 / 1 | 420 / 0 / 2 |
| OSFile25 (Server 2025) | 122 / 0 / 0 | 67 / 0 / 0 | 82 / 0 / 1 | 149 / 0 / 1 | 420 / 0 / 2 |

The skipped tests are those of the record of rc9a: the module version of the
run in the Server role, and case 9 in the Admin role, which needs the trusts
of the first lab.

### First lab

Passed / failed / skipped per edition
([FirstLab.csv](Acceptance-2026-11-12-artifact-5.0.0-FirstLab.csv)): Delegate
122 / 0 / 0, ServerAdmin 67 / 0 / 0, Admin (with case 9) 95 / 0 / 0, Server
152 / 0 / 1 (the module version of the run), in both editions: 436 / 0 / 1.
Windows PowerShell ran from 12:18 to 12:27 UTC and PowerShell 7 from 12:27 to
12:36 UTC.

### The module's own suite

Passed / failed / skipped, 12:45 to 13:06 UTC. Every configuration has 1,911
cases on the machines of the matrix lab and 1,910 on the host, which has no
DNS domain, so the test of the fully qualified name of this computer doesn't
exist there
([LocalSuite.csv](Acceptance-2026-11-12-artifact-5.0.0-LocalSuite.csv)).

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
operating-system builds are those of the record of rc9a (Windows Server 2019
17763.1217, 2022 20348.4773, and 2025 26100.32690; Windows 11 22H2 22621.525
and 26H1 28000.1836; the host 26100.33822); the virtual machines have
PowerShell 7.6.3, and the host PowerShell 7.6.10.

## Limits and open items

- This is the acceptance of one build. Another build of the same source is
  different bytes and would need the cells again.
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
- The runs CI #94 to #97 stay queued on GitHub. They hold nothing back; the
  force-cancel endpoint of the REST API or GitHub Support can remove them.
- The environment `powershell-gallery` keeps its required reviewer until the
  maintainer removes it; while it does, every run of a tag waits for an
  approval. `Docs/Contributing/05-Releasing.md` still accepts a stable
  release through the last prerelease; whether the acceptance of the artifact
  becomes the procedure is the maintainer's decision.
- The driver, the preparation script, and the chain scripts are helpers in the
  session files, not part of the kit.

## Evidence

The evidence is outside git, in the session folder
`C:\Users\install\.copilot\session-state\f097ed24-a01f-4896-9c61-d1a0208cbdff\files`:

- `stable-acceptance`: the run of this record. The artifact (`artifact`,
  `artifact-identity.json`) and its extracted packages (`published`, with
  `ModuleFiles-5.0.0.csv`); `driver.log` (with the SHA-256 of every chain
  script); the chain logs (`chain-published-a1.log`, `chain-suites-a2.log`,
  `chain-published-a2.log`); the cells (`live-matrix-a1`), the first lab
  (`live-a1`), and the suites (`localsuite-a2`); the checks (`verify-a1`,
  `verify-matrix-after-suites-a2.log`, `verify-client-a2.log`) and the gates
  of the client (`client-channel-a1.log`, `client-channel-a2.log`); the
  exported tables with the SHA-256 of their 81 input files (`tables`) and the
  four tables of this record (`record`); the identity check after the
  publication (`published-check`, with `Identity-5.0.0.json`), and the
  package that the Gallery served (`gallery-5.0.0.nupkg`).
- `scripts`: `Prepare-ArtifactAcceptance.ps1`, the driver
  (`Run-ArtifactAcceptance.ps1`), and the builder of the four tables
  (`Build-PublishedRecordTables.ps1 -Kind artifact`).

The chain scripts are those of the release gate, in
`C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns\scripts`.
