---
status: current
last-verified: 2026-10-10
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-10-10 15:45 UTC: the maintainer integrated the release-gate stack
into `master` (`6dd799f`, CI green): #116 (rc7, `8a6be9f`), #120
(`bdb9981`; it replaced #117, which GitHub closed unmerged when the branch
deletion after #116 removed its base, see Decision 15), #118 (`03bef2c`,
handoff 1, the paths), #119 (`fa0701b`, handoff 2, the operating-system
matrix), and #121 (the Memory Bank). He tagged `fa0701b` as `5.0.0-rc7` at about
12:20Z, and rc7 is published (Gallery 12:30:57Z, GitHub 12:31:09Z); 4.2.6 stays
the stable Gallery version. rc7 contains the Phase 2 behavior changes, the path
tests and fixes, and the three module fixes of the matrix (`962887a`,
`fdd7a8b`). The published rc7 passed its lab acceptance (gate 3) on the same
day, in the matrix and in the first lab, with the counts of the final local
candidate (record `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`). Stable
5.0.0 stays gated (Decision 21).

The maintainer asked on 2026-10-09 at 21:21 UTC to continue with the
release-gate handoffs and to decide and report later. The agent's decisions are
D1 to D47 in `decisions-night-2026-10-09.md` of the session files. Decisions
22 (Phase 2), 23 (the #34 dossier), and 24 (the matrix) are proposed: the agent
confirmed Decision 22 under the delegation, and neither that nor any risk
acceptance is the maintainer's.

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
- Raw evidence is outside git: the session folder
  `4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files` (`qg-paths`, the matrix runs, the
  night log) and
  `26f151b6-e46f-49bd-9398-b27e20603949\files\quality-gate-3442194-20261009`.

## Next step

1. Gate 3 is done for the published rc7 (the record above). A changed binary
   (rc8, or the build of 5.0.0) needs the same cells again; the release
   procedure accepts the last prerelease for the stable build (his decision).
   Open: keep or replace the matrix VMs (about 60 GB) and the evaluation client
   (it shuts down every hour; `OSWin11E` is off), and a domain cell for Windows
   11 26H1, whose client loses the secure channel to the Server 2025 domain
   controller. A kit script for the whole sequence would make the repetition
   one command (the driver is `Run-Gate3.ps1` in the evidence; not in the kit).
2. The change that sets the next version (rc8 or 5.0.0) adds `5.0.0-rc7` to
   `$publishedVersions`; adding it earlier fails the reuse test (deployment
   notes). Every release step is the maintainer's.
3. He decides the open items of the paths report: `FileSecurity` conversions,
   `RemoveAll` account filters, lazy path overloads, abandoned
   `PrivilegeEnabler`, dot patterns of `Get-ChildItem2 -Filter`, the 17
   owner-restore handlers without the later-command check, unused classes
   (Decisions 21/22). He also confirms or changes the proposed Decisions 22 and
   24.
4. #34 stays open (Decision 23; no reply since 2026-10-06): the maintainer
   chooses between waiting for a test of the published candidate on the
   NetApp, EMC, and IBM ESS servers of the reporters (checklist:
   `Tests/Lab/Non-Windows-File-Server-Test.md`) and accepting the untested
   risk with a release-note caveat. No agent can accept it.
5. He decides the two LOW findings of the security review (record, Limits):
   the swallowed initialization errors of `GetEffectiveAccess` (a false "no
   access" instead of an error on an OS that refuses at initialization; fix:
   record the exceptions in `authzException`, with a regression test and a
   check of "the error stays" in the help and CHANGELOG), and the ACL of the
   stage folders under `C:\` in the lab kit (they inherit Authenticated Users:
   Modify; protecting them is a design change of the controller and needs a new
   acceptance). The help could also say that a local standard user who asks
   about a domain account still gets "Access is denied".
6. Do not release stable 5.0.0 or equate a percentage with gate closure.
