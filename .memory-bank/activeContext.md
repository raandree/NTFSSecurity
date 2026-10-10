---
status: current
last-verified: 2026-10-10
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The maintainer asked on 2026-10-09 at 21:21 UTC to continue with the release-gate
handoffs and to decide and report later. Handoff 1 (paths) is draft #118
(`83149ee`, CI green; stacked on #117 and #116, all open; rc6 is the latest
published candidate, 4.2.6 the stable Gallery version). Handoff 2 (operating-system
matrix) is the local branch `ai/quality-gate-lab-matrix`, stacked on #118 and not
pushed: the lab `NtfsSecurityOsMatrixLab`, three fixes of the module in two commits
that the matrix found (`962887a`, `fdd7a8b`), the kit, the controller changes, and the
record `Tests/Lab/Acceptance-2026-10-10-os-matrix.md` (Decision 24, proposed).
The final local candidate `fdd7a8b` passes the module's suite on five operating
systems and the host (24 runs, no failure) and the live controller in three
cells of the matrix (1,374 passed, 0 failed, 12 skipped) and in the first lab,
where case 9 runs (245 passed, 0 failed, 1 skipped per edition). Handoff 3: Decision 22 was confirmed
under the delegation and stays proposed; nothing is published. Handoff 4:
Decision 23 (the #34 dossier); the risk acceptance is the maintainer's. The
agent's decisions of the night are D1 to D42 in
`decisions-night-2026-10-09.md` of the session files. Stable 5.0.0 stays gated.

The earlier state of handoff 1, from the reviewed head `f11ff41` of #117: 28
commits, which the maintainer pushed as draft #118. Every C# method that no test
visits is classified (223 explained, 8 open for the maintainer), and the
other paths have behavior tests. Eleven defects were fixed, ten of them
with a regression guard that is red before the fix and green after it (owner
restore, `InheritedFrom`, a later command that ends the pipeline or throws,
also at the error, verbose, and debug streams, `-Filter` brackets, null, and
`*.*`, public object APIs, a privilege left enabled); the leak of a native
buffer has no observable guard. The lab acceptance of those fixes was repeated
on 2026-10-09 (below); the published package still needs its own acceptance
in gate 3. Decisions 21/22 and stable 5.0.0
remain gated; Decision 22 is proposed: the agent confirmed all ten choices
on 2026-10-09 under the maintainer's delegation, and his own confirmation is
open.

## Evidence

- rc6 Release run `37839669028`, attempt 2, succeeded; GitHub prerelease
  with zip appeared 2026-10-09 07:01:34 UTC. First attempt proves HTTP 409
  after Gallery publication, not the previously assumed retry chronology.
- #116 is open, base master, head `d25647d`, CI build/wiki passed. rc7
  publication is pending. The follow-up does not change that PR's head.
- Local changes: deletion/ownership guards (`a97e46f`); all scopes and
  inheritance (`e7ee203`); absolute basic-user results (`51dec86`);
  exact-package publication recovery (`95b827e`); first-hidden-item fix
  (`d610372`); Force/descriptor guards (`3442194`); SMB regression above.
- Hidden omission was reproduced in all four configurations before the
  fix. No parameter/design change. Publication tests are wholly mocked;
  exact ordinal SHA-512 identity is required, no real upload occurred.
- At `3442194` (start of Handoff 1): 914 cases per configuration, 2,641/3,559
  sequence points (74.21%), 974/1,933 branches (50.39%), 918 unvisited
  points. All skipped templates had executed counterparts.
- Handoff 1 result at `5a5d58b` (frozen Release, four configurations, CI
  wrappers, then AltCover): 1,310 cases per configuration, zero failures;
  passed/skipped: elevated Desktop 1,286/24, Core 1,255/55; basic Desktop
  1,076/234, Core 1,045/265. Coverage 3,192/3,634 sequence points (87.84%),
  1,273/1,978 branches (64.36%); 231 methods with 442 points stay unvisited,
  all classified: 223 explained, 8 open. Skip eligibility was checked by row
  from a second full run per configuration: all 578 skipped rows (137
  distinct tests) are executed in two other configurations.
- Mutation rounds on the frozen tree at `5a5d58b`: 26 mutations in four
  rounds; 25 are detected by their guard in every configuration where it
  runs, and M25 (the check by type, an equivalent mutant) survives as
  expected. At `d61dffa` three had escaped (the verbose and debug rows ran
  under the CI runner's `Stop`, and an Init test could not fail for its
  branch), which led to `f4a16e1`. A first round at `630926f` had let one
  mutation escape, which led to the `-Filter` bracket defect.
- Red/green matrix (measured after the last measurement, because the first
  red runs were not kept): the final tests of the eight files that guard the
  fixes (650 cases per configuration) over the production code of ten states
  of the branch, built in Release and run with the focused runner (it sets
  `Stop` like the CI wrappers) in the four configurations. 76 rows (73 in the
  basic configurations) fail at the base `f11ff41`, each is green at the step
  of its fix, none breaks later, and `d44a200` has none (the control). Defect
  9 (the native buffer) has no guard. The matrix does not show that a test was
  written before its fix: each fix commit carries both, and the red runs of
  that time were not kept.
- Review: custom `security-reviewer` could not start (model unavailable); the
  built-in read-only `code-review` agent made nine static passes: no Blocker
  or Major; its Minor findings led to the `*.*`, help, test, later-command,
  error-stream, and privilege fixes. Report:
  `Tests/Coverage/Quality-Gate-Paths-2026-10-09.md` with an appendix of
  explanations and CSV rows; raw evidence is in the session folder
  `4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files\qg-paths`.
- Live packaged candidate, 09:20 to 09:51 UTC: 330 passed, zero failed,
  two expected Server-module skips. Published rc6: 326 passed, four
  expected failures (Hidden and rc7 warning text in each edition), two
  skips. Tested folder and all 11 ZIP files are byte-identical.
- Temporary host result verifier failed on Desktop JSON wrapping/full
  test names; corrected verification passed on unchanged raw results in
  both editions. Cleanup wrapper's broad Error.Count was not acceptance
  proof. Independent probes verified all fixture objects/members/profiles
  gone from six machines. Raw failing markers and corrected evidence kept.
- Review of the lab candidate: one read-only independent code review
  approved, high confidence, no significant findings or confirmed exploit.
- Six checkpoints exist but report Standard, even after a successful
  temporary ProductionOnly probe; policy restored, no restore performed.
  Do not claim verified Production rollback evidence.
- Lab acceptance of the paths fixes, 20:41 to 21:42 UTC on 2026-10-09: the
  candidate `83149ee` and its base `f11ff41` ran the same 244 tests per
  edition (78 new, case 10) from their extracted packages. Candidate 486
  passed, 0 failed, 2 expected skips; baseline 338 passed, 148 failed, each
  green on the candidate; both editions gave the same counts. Fixture removal
  verified by a separate read-only check in four domains and on both file
  machines; six checkpoints (Standard type, no restore). Record, results CSV,
  and limits: `Tests/Lab/Acceptance-2026-10-09-quality-gate-paths.md`. This
  covers the gate-3 handoff table of the path report, except the published
  package and the other operating systems.
- Wider matrix not deployed: 13 Server 2025 VMs; Windows 11/2019/2022
  media present, OS detection cache empty. #34 has no reply since Oct 6.
- Full evidence: session artifact `quality-gate-3442194-20261009`;
  repository report `Tests/Lab/Acceptance-2026-10-09-quality-gate.md`.
- Operating-system matrix, 2026-10-10 (record `Tests/Lab/Acceptance-2026-10-10-os-matrix.md`
  with CSV tables): the suite of the final candidate `fdd7a8b` on OSFile19,
  OSFile22, OSFile25, OSWin11E, OSWin11, and the host, four configurations each,
  zero failures, skipped tests identical to the host's; the baseline `83149ee`
  (run on OSFile22 and OSFile25) fails 4 elevated and 20 basic-user tests. Live: run
  `rc7l`, three cells, 1,374 passed, 0 failed, 12 skipped. First lab (run `fl1`,
  case 9 included, both editions): 245 passed, 0 failed, 1 skipped per edition,
  fixture removed and verified clean. The Admin-role
  effective-access failures of the earlier cells were not the module: in a replay
  (`ab0` to `ab6`) the baseline failed two of three cells and the final candidate
  one of three (not counting the warm-up `ab0`), and one model (the remote
  authorization managers answer for an account name for about ten minutes after
  the account was created again) fits all 43 Admin-role runs of 27 cells; the
  Windows mechanism is unknown. The controller now names the account of case 3
  anew for each fixture (`1dec389`); four more cells with it (`ab7` to `ab10`)
  passed, two of them where the model predicts a failure for a reused name.
  Reviewed by the built-in code-review agent (custom `security-reviewer`
  unavailable): approve with Minor, fixed; a second review found one Major
  (record accuracy), addressed by the replay; a follow-up review found no
  Blocker or Major and five Minors, corrected; a second follow-up review found no
  Blocker or Major and four Minors, corrected. State of the labs at 07:30 UTC on
  2026-10-10: no fixture and no probe residue in either lab (`Verify` of the
  matrix lab 06:54, of the first lab 07:29); the six VMs of the matrix run, and
  `OSWin11E` (started 06:44) shuts itself down about an hour after its start.

## Next step

1. The maintainer pushes `ai/quality-gate-lab-matrix` as a draft PR with base
   `ai/quality-gate-paths` and decides which of the module fixes belong to rc7
   (two commits: `962887a` holds two fixes, `fdd7a8b` one). He reviews and
   integrates the stack: #116, then #117, then #118, then the matrix branch
   (Decision 24).
2. He decides the open items listed in the paths report: `FileSecurity`
   conversions, `RemoveAll` account filters, lazy path overloads, abandoned
   `PrivilegeEnabler`, dot patterns of `Get-ChildItem2 -Filter`, the 17
   owner-restore handlers without the later-command check, unused classes
   (Decisions 21/22).
3. Gate 3: accept the published package in the first lab and in every cell of
   the matrix (`Run-MatrixSequence.ps1 -Version`) before the candidate counts as
   accepted; no local upload. The paths fixes were accepted locally (record
   above).
4. Retain stacked-PR order (15): #116, then #117, then #118; a local merge
   in that order gives exactly the tree of #118. Confirm or change Decision
   22.
5. #34 stays open (Decision 23): the maintainer chooses between waiting for a
   test of the published candidate on the NetApp, EMC, and IBM ESS servers of
   the reporters (checklist: `Tests/Lab/Non-Windows-File-Server-Test.md`) and
   accepting the untested risk with a release-note caveat. No agent can
   accept it.
6. Do not release stable 5.0.0 or equate a percentage with gate closure.
