---
status: current
last-verified: 2026-11-11
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-11-11, 19:30 UTC: 5.0.0-rc9a is published and accepted. The
maintainer merged #135 (`c135062`, 13:58Z) and pushed the tag `5.0.0-rc9a`;
the tag run `43039152538` published it (Gallery 14:42:14Z, GitHub 14:42:22Z),
and `Test-PublishedRelease.ps1` verified it at 14:57Z. rc9a is the code of rc9
built again (the module folders differ from `5.0.0-rc9` only in the manifest)
with the final release notes: the note about #34 and the six known limits in
`[Unreleased]` (Decision 21, "Another prerelease before stable"). Its label
sorts after rc9 (NuGet.Versioning ranks `5.0.0-rc10` below `5.0.0-rc9`). The
lab acceptance of the published bytes, with the kit of the tag (case 11), ran
from 16:29 to 17:51 UTC in one detached driver: the three cells 2,520 / 0 / 12
(420 / 0 / 2 per edition and cell), the first lab 436 / 0 / 1 per edition, the
suite in 24 runs 0 failed (1,911 cases per configuration, the host 1,910; no
skip differs from the host), every end state CLEAN; the counts equal those of
rc9 with case 11. Record `Tests/Lab/Acceptance-2026-11-11-published-rc9a.md`
on `ai/acceptance-published-rc9a` (worktree `C:\Temp\ntfs-rc9a\acceptance`);
the maintainer pushes and merges it. The lab machines are saved again. At
19:20 UTC he chose to prove the stable bytes live before they are published
(Next step 2); the stable branch `ai/release-5.0.0-final` (worktree
`C:\Temp\ntfs-rc9a\stable`) is prepared locally.

Handoff 6 (2026-11-10 to 11) closed criteria 2 to 4 of Decision 21 for the
code of rc9, which rc9a ships unchanged:

- **Limits (criterion 4).** `### Known limits` with six items is in
  `[Unreleased]` on `ai/release-5.0.0-rc9a`, copied from `ai/release-5.0.0`
  (`c7cad81`). Five were reproduced on the published rc9 in both
  editions, with exit codes and output kept in `E\rc9-coverage\probes`; the
  sixth, `PrivilegeEnabler`, a public class of `ProcessPrivileges.dll` that no
  cmdlet uses, I read from the source of the tag. Two first drafts were wrong
  and are corrected: `PrivilegeEnabler` named `Security2.dll` and said that the
  cmdlets dispose their enablers; the collection that contains itself said
  "stack overflow" for both editions, but PowerShell 7 ends the process without
  a message (exit code 0xC0000005). His choice of rc9a with rc9's code
  (2026-11-11) confirms the six limits and that none is fixed.
- **Coverage and skips (criteria 3 and 2).** Branch `ai/rc9-tests` (#134,
  merged): the tag measured in four
  configurations, 3,666 of 4,074 sequence points; 52 new unit cases (suite 2,214
  per configuration), 3,672 of 4,074 (90.13%); 169 unvisited methods (402
  points, 88 explicit branch points) classified by 35 rules, none open, ten
  handlers without a test of the later-command check (nine of Decision 27 and
  `Get-NTFSSecurityDescriptor`); 417 skipped rows of 214 tests, each executed
  in two other configurations. Report
  `Tests/Coverage/Quality-Gate-rc9-2026-11-10.md`.
- **Live case 11 (criterion 5, the rc9 changes).** 191 tests per edition. On
  the published rc8, 79 fail, each for the documented reason, and 112 pass on
  both; on the published rc9 all pass in the first lab (436 / 0 / 1 per
  edition) and in the three cells (420 / 0 / 2 per edition and cell, 2,520 / 0 /
  12 in all), and the module's suite passed in 24 runs (1,911 cases per
  configuration, the host 1,910). Both labs CLEAN. Addendum
  `Tests/Lab/Acceptance-2026-11-10-published-rc9-case-11.md`. The final unit
  suite on the tip passed in four configurations (2,214 cases each, 0 failed;
  `E\qg-unknowns\final-suite-tip`).
- **Reviews.** The built-in `code-review` agent (the custom `security-reviewer`
  can't start) read the work three times. Tests, fixtures, and the coverage
  report: no finding in the tests, two Minor ones in the report (fixed). Release
  notes and the stable branch: one Minor (the PowerShell 7 outcome of the
  collection that contains itself; probed on the published rc9, wording
  corrected), one more on the re-check (five cmdlets read `GetInheritedFrom`,
  not two; probed, `c7cad81`), and Nits (fixed; a sentence in the body of
  `7fab81a` says "build" for "source", left as it is because the branch isn't
  rewritten, and named in the PR body). Records, Memory Bank, PR bodies, and
  commands: one Major (a stale commit count) and six Minor ones (claims that
  said more than the evidence, a stale line count, probe files that no table
  listed), all fixed.
- **No new product defect** was found by the tests, the probes, or the reviews,
  beyond the six accepted limits; a defect would need rc10 (the stop rule).

rc9 (and so rc9a) contains the changes of Decision 27 ("Built in rc9": the
five piped parameters as `object`, the descriptor sets that go on, the 17
owner-restore handlers, the one-matcher filter, the library fixes, the error of
`Get-NTFSOrphanedAccess`, position 1 of `-SecurityDescriptor`); its suite and
two review rounds ended with "no finding" on `696ac38`. The earlier
acceptances are rc7 (2026-10-10), rc8 (2026-10-20), and rc9 (2026-11-10, in
four parts; with case 11 on 2026-11-11); see `progress.md` and `Tests/Lab`.

Two gates closed on 2026-11-10, in answer to an explicit question: he accepts
the untested risk of #34 (Decision 23, option 2: release 5.0.0 with the
caveat) and says that he checked `PSGALLERY_API_KEY` (a secret that the agent
can't read; nothing about it is recorded here). The delegated decisions of
2026-10-09 and 10 are D1 to D47 in `decisions-night-2026-10-09.md` of the
session files.

## Evidence

- Raw evidence is outside git, in the session folder
  `C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files`
  (`E`). Handoff 6: `E\rc9-coverage` (the first measurement `m1`, the probes of
  the limits, the mutation runs), `E\qg-unknowns\rc9-r1` and
  `eligibility-rc9-r1` (the second measurement, the analysis, the skips by
  row), `E\qg-unknowns\ext-d1` and `ext-d2` (the detection runs on rc9 and
  rc8, with `compare`),
  `E\qg-unknowns\ext-a1` (the acceptance chains a1 and a2 and their `tables`),
  and `E\qg-unknowns\scripts` (the helpers: `Chain-Extended.ps1`,
  `Chain-SuiteOnly2.ps1`, `Run-LiveDetect.ps1`, `Compare-Detect.ps1`,
  `Build-Rc9ReportTables.ps1`, `Build-Case11Tables.ps1`, and the older ones;
  inspect before reuse). The Evidence tables of the report and the manifest
  `ext-a1\evidence-manifest.csv` list the files with their SHA-256.
- Evidence of rc9 and of the earlier gates: `E\rc9` (the specs, the suites of
  the integration, the probes, the published rc8 and rc9, the four parts of the
  acceptance with `evidence-manifest.csv`), the session folders
  `4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files`,
  `26f151b6-e46f-49bd-9398-b27e20603949\files\quality-gate-3442194-20261009`,
  and `E\qg-unknowns\rc8-published`; the published hashes are in the deployment
  notes. The review probes are in `C:\Temp\ntfs-rc9\review*-probes-*`; the
  worktrees under `C:\Temp\ntfs-rc9` and the junctions in them are temporary.
- Milestones of earlier gates are in `progress.md` and in the records and
  reports under `Tests/Lab` and `Tests/Coverage`.
- Reviews: the custom `security-reviewer` can't start (its model is
  unavailable; no override); the built-in `code-review` agent reviewed the paths
  work, the matrix, rc8, rc9, the stable change (2026-11-10, "no finding"), and
  the work of Handoff 6; the built-in `security-review` agent found no
  exploitable vulnerability and two LOW items for the maintainer (Next step 5).
- Six checkpoints of the lab report Standard even after a successful
  ProductionOnly probe; policy restored, no restore performed: don't claim
  verified Production rollback evidence.

## Next step

1. The record of the acceptance of rc9a (`ai/acceptance-published-rc9a`, the
   record, its four tables, and the Memory Bank): he pushes it, opens the pull
   request, and merges it with a merge commit before the stable pull request.
2. The stable bytes are proven live before they are published (Decision 21,
   "Live proof of the stable bytes"): he adds a required reviewer to the
   environment `powershell-gallery`, merges the stable pull request
   (`ai/release-5.0.0-final`, stacked on the record: no `Prerelease`,
   `## [5.0.0] - 2026-11-11`, `5.0.0-rc9a` in `$publishedVersions`; the
   CHANGELOG and the manifest equal the reviewed `c7cad81`), and pushes the
   tag `5.0.0`. The tag run builds and tests, then waits. The agent runs
   `Prepare-ArtifactAcceptance.ps1 -RunId <run>` and
   `Run-ArtifactAcceptance.ps1` (deployment notes) on the artifact `packages`
   and writes the record. If it passes, he approves, and the agent compares
   the published nupkg with the tested one (`Test-PublishedRelease.ps1
   -Version 5.0.0`); if it fails, he rejects, deletes the tag, and the fix
   goes through another prerelease. The date in the CHANGELOG must be the day
   of the approval (UTC).
3. Unchanged since the rc9 acceptance with case 11: what the lab can't show
   (ten of the 17 handlers that retry as the owner, the new `ReadSecurityError`
   of `Get-NTFSOrphanedAccess`, the changes that don't depend on where the item
   is), case 9 only in the first lab, no live cell for Windows 11 26H1, and no
   file server that isn't Windows (#34 caveat).
4. #34: decided on 2026-11-10 (Decision 23, option 2). The issue has no comment
   since 2026-10-19 and no tester result. The caveat names the file servers that
   the matrix tested (Windows Server 2019, 2022, 2025) and says where to report
   after the archive.
5. His to confirm: the explanations of the 169 methods (the report's open
   items).
6. Open housekeeping: keep or replace the matrix VMs (about 60 GB, saved between
   runs) and the evaluation client (it shuts down an hour after each start;
   `OSWin11E` is off); a domain cell for Windows 11 26H1, whose client loses the
   secure channel to the Server 2025 domain controller; the cleanup list before
   the archive (AppVeyor, Read the Docs, wiki, `test/transfer`, old
   checkpoints).
   Of the two LOW findings of the security review, the swallowed initialization
   errors are fixed in rc8; he still decides the ACL of the stage folders under
   `C:\` in the lab kit (they inherit Authenticated Users: Modify; protecting
   them is a design change of the controller and needs a new acceptance).
7. Known limits for the archive are in the CHANGELOG now (Decision 27 has the
   reasoning). Do not equate a percentage with gate closure.
