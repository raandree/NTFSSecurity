---
status: current
last-verified: 2026-10-21
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-10-21: 5.0.0-rc8 is published and accepted. The
maintainer merged #126 (the decisions of 2026-10-19) and #127 (`c719197`: the
fix of the false "no access" of `Get-NTFSEffectiveAccess`, the known limit of
the hard-link cmdlets in the pages and the CHANGELOG, and the label `rc8`) and
tagged `5.0.0-rc8` at about 10:28Z. The CI run `39408140862` passed, and the
Gallery has rc8 since 10:40:58Z, GitHub since 10:41:07Z. The identity check
passed. The lab acceptance of the published bytes passed in one detached driver
(68 minutes, 10:38 to 11:47Z): three cells 1,374/0/12, the suite in 24 runs on
six machine classes, the first lab 245/0/1 per edition, every end state CLEAN
(record `Tests/Lab/Acceptance-2026-10-20-published-rc8.md`, #128). The boundary
of the new error, a computer name of 32,718 characters, holds on Server 2019,
2022, 2025, and Windows 11 26H1. He merged the record, #128, on 2026-10-21 at
05:48Z, the tests-only round for the plain gaps (#129, 08:24Z; Next step 6),
and this Memory Bank (#130, 08:47Z); `master` is `d0cb57c`. The new tests gave
the same counts on the runner (three CI runs) and on six machine classes of the
labs (24 runs, 0 failed). A probe found that a typo in a piped `AccessType`
silently creates an Allow entry. He decided (Decision 27) that rc9 fixes that
family and the items 3 to 7 of its sheet, with a review, and chose the
designs. Four work items run in worktrees under `C:\Temp\ntfs-rc9` (branch
`ai/rc9-before-stable`; specs in the session folder `files\rc9\specs`). Open
before the stable pull request: rc9 (integration, validation, review,
acceptance of about 70 minutes), his decision on #34 on 2026-11-02, and his
check of `PSGALLERY_API_KEY`. The stable change then touches only the label,
the CHANGELOG, and `$publishedVersions`.

State at 2026-10-10: the maintainer integrated the release-gate stack into
`master` (#116, #120, #118, #119, #121; `fa0701b`, CI green; GitHub closed #117
unmerged when the branch deletion removed its base, Decision 15) and tagged rc7
(Gallery 12:30:57Z). The published rc7 passed its lab acceptance the same day
(record `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`). The agent's
delegated decisions of 2026-10-09 and 10 are D1 to D47 in
`decisions-night-2026-10-09.md` of the session files; the maintainer accepted
Decisions 22 and 24 on 2026-10-19 and decides 23 on 2026-11-02.

## Evidence

- rc6 Release run `37839669028`, attempt 2, succeeded; GitHub prerelease with
  zip appeared 2026-10-09 07:01:34 UTC. The first attempt proves HTTP 409
  after Gallery publication, not the earlier assumed retry chronology.
- Integration on 2026-10-10 (UTC): #116 merged 09:10, #117 closed unmerged
  09:10:16 (events `base_ref_deleted`, `closed`), #120 merged 10:50, #118
  11:12, #119 11:28, head branches deleted 11:34, CI on `master` at `fa0701b`
  green 11:40. A `git merge-tree` simulation of the chain was conflict-free and
  ended in the tree of the matrix branch.
- rc7 on 2026-10-10: tag at `fa0701b` about 12:20Z, CI run `38051611526`
  green, Gallery 12:30:57Z, GitHub 12:31:09Z. `Test-PublishedRelease.ps1`
  (12:33Z): tag commit on `master`, Gallery SHA-512 matches the nupkg, 11
  module files identical in nupkg and zip, manifest `5.0.0-rc7`; hashes in the
  deployment notes, evidence in the session folder `published-rc7`.
- Gate 3 on the published rc7, 14:29 to 15:30 UTC (one detached driver; record
  `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`, evidence `gate3-rc7` with
  a manifest): the three matrix cells (OSFile19, 22, 25 with OSWin11E, both
  editions) 1,374 passed, 0 failed, 12 skipped, `LIVE_RESULT_VERIFIED` and
  CLEAN in each; the suite in 24 runs on six machine classes without a failure
  and with the host's skipped tests; the first lab with case 9 245 / 0 / 1 per
  edition, CLEAN in four domains and on both machines. Each controller run
  downloaded the package of the identity check (nupkg and DLL hashes equal).
  Same counts as the final local candidate; no checkpoint was taken.
- Handoff 1 (paths), measured at `5a5d58b` (frozen Release, four configurations,
  CI wrappers, then AltCover): 1,310 cases per configuration, zero failures
  (baseline `3442194`: 914 cases); coverage 3,192/3,634 sequence points
  (87.84%) and 1,273/1,978 branches (64.36%), against 74.21% and 50.39%. All 231
  methods with 442 unvisited points are classified: 223 explained, 8 open for
  the maintainer. Skip eligibility was checked by row: all 578 skipped rows
  (137 distinct tests) are executed in two other configurations.
- Eleven defects were fixed, ten with a guard that is red before the fix and
  green after it (a red/green matrix over ten states of the branch: 76 rows
  red at the base `f11ff41`, none after the last fix; the leak of a native
  buffer has no guard). Mutation rounds at `5a5d58b`: 25 of 26 detected, M25
  (the check by type) an equivalent mutant. The matrix doesn't show that a test
  preceded its fix: each fix commit carries both. Report:
  `Tests/Coverage/Quality-Gate-Paths-2026-10-09.md`.
- Reviews: the custom `security-reviewer` can't start (its model is
  unavailable; no override). The built-in `code-review` agent made nine static
  passes of the paths work (no Blocker or Major) and four rounds on the matrix
  (one Major, record accuracy, resolved by the replay; Minors corrected); the
  built-in `security-review` agent found no exploitable vulnerability and two
  LOW items left for the maintainer (Next step 5).
- Live candidate of 2026-10-09 (09:20 to 09:51 UTC): 330 passed, 0 failed, 2
  expected skips; published rc6: 326 passed, 4 expected failures, 2 skips; the
  11 tested files match the ZIP. Independent probes verified the fixture
  removal on six machines (`Tests/Lab/Acceptance-2026-10-09-quality-gate.md`).
- Six checkpoints report Standard even after a successful ProductionOnly probe;
  policy restored, no restore performed: don't claim verified Production
  rollback evidence.
- Lab acceptance of the paths fixes, 2026-10-09 20:41 to 21:42 UTC: candidate
  `83149ee` against its base `f11ff41`, the same 244 tests per edition (78
  new): 486 passed, 0 failed, 2 expected skips against 338 passed, 148 failed
  (each green on the candidate); fixture removal verified. Record:
  `Tests/Lab/Acceptance-2026-10-09-quality-gate-paths.md`.
- Operating-system matrix, 2026-10-10 (record
  `Tests/Lab/Acceptance-2026-10-10-os-matrix.md` with CSV tables): the suite of
  the final candidate `fdd7a8b` passes on OSFile19/22/25, OSWin11E, OSWin11, and
  the host (24 runs, no failure; the baseline `83149ee` fails 4 elevated and 20
  basic-user tests on OSFile22 and OSFile25); the live controller passes in
  three cells (1,374 passed, 0 failed, 12 skipped) and in the first lab with
  case 9 (245 passed, 0 failed, 1 skipped per edition; fixture removed and
  verified). The Admin-role effective-access failures in earlier cells were
  stale account state, not the module: in a replay the baseline failed two of
  three cells and the candidate one, and one lifetime of about ten minutes fits
  43 runs of 27 cells (the Windows mechanism is unknown). The controller names
  the case-3 account anew for each fixture (`1dec389`); four more cells with it
  passed. A dry run of `Run-MatrixSequence.ps1 -Version 5.0.0-rc6` showed that
  the published-package path works. Labs at 07:50 UTC on 2026-10-10: no fixture
  or probe residue; `OSWin11E` shuts itself down an hour after its start.
- Handoff 5, the coverage unknowns, 2026-10-10 to 11 (report
  `Tests/Coverage/Quality-Gate-Unknowns-2026-10-10.md`; raw evidence in the
  session folder `816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns`
  with a hash manifest). rc7 measured at `fa0701b` (four frozen
  configurations, AltCover): 3,198/3,649 sequence points (87.64%), 1,090/1,168
  explicit branch points; 232 unvisited methods, all classified. Live suite on
  an instrumented copy (first lab and three cells) and unit suite on
  `OSFile25`: together +9 sequence and +4 explicit branch points (the code of
  `fdd7a8b`); no test or probe reaches the audit ownership retry or the audit
  read denial. 101 new `It` blocks; 7 of 64 parameter sets closed, 51 partly,
  1 open, 4 left to the maintainer. Cultures `de-DE` and `tr-TR`: two defects,
  fixed. The piped
  `AppliesTo` (Decision 26, debugging insights): fixed in `93ed2c7`; the
  independent reviews then found a carry-over of the scope between piped
  objects (`9783d2a`; rc7 had it for descriptor objects) and two false
  sentences of the documents about empty values (`7bc7925`, `2112ee3`). Final
  commit `2112ee3`, product code of `9783d2a` (its help file differs from the
  package that the labs accepted): 1,492 cases per configuration, 3,266/3,668
  points, 183 unvisited methods, all classified. The labs accepted the package
  (`ap7`, `ap8`): first lab 245/0/1 per edition; the 22 files on
  `OSFile19/22/25` and `OSWin11` 1,189/0 in 16 configurations; the three cells
  229/0/2 per edition; all end states clean at 13:45Z. The first start of the
  cells did nothing: a `powershell.exe` that PowerShell 7 starts inherits its
  `PSModulePath` (lab README). Server Core, ARM64, a localized system, and
  non-Windows servers are out of scope (Decision 25).
- rc8, 2026-10-20: fix (b) test-first on `ai/fix-effective-access-init-errors`.
  A `-ServerName` of 40,000 characters gave `Synchronize` and no error before
  and gives an error now; two tests were red and are green in four
  configurations, and the suite has 1,494 cases per configuration, 0 failed.
  The independent review (`code-review`) found one Minor, the warning "based on
  this computer" before the error (fixed, with tests), and three Nits. The
  acceptance evidence is `rc8-published` in the session folder
  `816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns` (430 files, with a
  manifest); the published hashes are in the deployment notes.
- Raw evidence is outside git: the session folder
  `4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files` (`qg-paths`, the matrix runs, the
  night log) and
  `26f151b6-e46f-49bd-9398-b27e20603949\files\quality-gate-3442194-20261009`.

## Next step

1. Gate 3 is done for the published rc7 and rc8 (the records). The stable build
   is accepted through rc8 (Decision 21, "Closing the gate"). Open: keep or
   replace the matrix VMs (about 60 GB, saved between runs) and the evaluation
   client (it shuts down every hour; `OSWin11E` is off), and a domain cell for
   Windows 11 26H1, whose client loses the secure channel to the Server 2025
   domain controller. `Chain-Published.ps1` in the session files runs the whole
   sequence (not in the kit; deployment notes).
2. The stable pull request: no `Prerelease`, `## [5.0.0] - <date>` with an empty
   `[Unreleased]` and the links, and `5.0.0-rc8` in `$publishedVersions` (the
   list ends at rc7 now). The maintainer checks the expiry of
   `PSGALLERY_API_KEY` first, merges, and tags. Every release step is his.
3. Decision 27 (2026-10-21): rc9 changes the library-only items, the dot
   patterns of `Get-ChildItem2 -Filter`, the 17 owner-restore handlers, the
   errors of the descriptor sets, and three inconsistencies; the designs are
   chosen, four work items are in progress. Decisions 22 and 24 are accepted.
4. #34 waits for a tester until 2026-11-02 (Decision 23, option 3; the
   follow-up went up on 2026-10-19, no reply yet; checklist:
   `Tests/Lab/Non-Windows-File-Server-Test.md`). On that date the maintainer
   chooses between waiting longer and accepting the untested risk with a
   release-note caveat. No agent can accept it.
5. Of the two LOW findings of the security review (record, Limits), the
   swallowed initialization errors of `GetEffectiveAccess` are fixed in rc8
   (`25fe775`, #127): an error instead of a false "no access", and the warning
   only with a result. He still decides the other: the ACL of the stage
   folders under `C:\` in the lab kit (they inherit Authenticated Users:
   Modify; protecting them is a design change of the controller and needs a new
   acceptance). rc9 adds to the help that a local standard user who asks about
   a domain account still gets "Access is denied" (Decision 27).
6. Handoff 5 is done and merged (Evidence). Decided on 2026-10-19 (Decision
   21): the hard-link names under another root stay a known limit; the pages
   and the CHANGELOG say so since rc8. The tests-only round for the plain items
   (68 `budget` mentions) ran on 2026-10-20: four implementers, one
   `ParameterSets.*` file each, merged as #129: 89 `It` blocks, 121 cases, the
   suite 1,494 to 1,615 per configuration, 0 failed; 38 of 64 sets closed, 26
   with a leftover (16 Limit, 7 MaintainerDecision, 3 would-pin), no defect;
   report `Tests/Coverage/Quality-Gate-Test-Round-2026-10-20.md`. The runner's
   counts equal the local run in three CI runs. No plain gap is left. A defect
   that a test finds needs his decision and rc9. Decision 27 settles the rest:
   rc9 fixes the 10 rows and the piped optional parameters (designs to
   follow); the audit paths over SMB are accepted (#34); the tests for the 8
   getters follow rc9.
7. Do not release stable 5.0.0 or equate a percentage with gate closure.
