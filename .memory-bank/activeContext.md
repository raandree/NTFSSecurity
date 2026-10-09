---
status: current
last-verified: 2026-10-09
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Handoff 1 of the quality gate is finished on `ai/quality-gate-paths`, from the
reviewed head `f11ff41` of #117: 28 commits, which the maintainer pushed as
draft #118 (CI green on `83149ee`). Both
stacked PRs stay open and green; rc6 remains the latest published
candidate and 4.2.6 the stable Gallery version. Every C# method that no test
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

## Next step

1. The maintainer reviews and integrates `ai/quality-gate-paths` (stacked on
   #117; no remote change was made here) and decides the open items listed
   in the report: `FileSecurity` conversions, `RemoveAll` account filters,
   lazy path overloads, abandoned `PrivilegeEnabler`, dot patterns of
   `Get-ChildItem2 -Filter`, the 17 owner-restore handlers without the
   later-command check, unused classes (Decisions 21/22).
2. Gate 3: the affected live acceptance of the paths fixes is repeated (record
   above). Accept the published package again before the next candidate counts
   as accepted; no local upload.
3. Retain stacked-PR order (15), obtain Decision 22 review, finish the OS
   matrix and obtain or explicitly accept #34 feedback through other gates.
4. Do not release stable 5.0.0 or equate a percentage with gate closure.
