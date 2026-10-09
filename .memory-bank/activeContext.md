---
status: current
last-verified: 2026-10-09
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Handoff 1 is in progress on `ai/quality-gate-paths`, from reviewed #117
head `f11ff41`. Both stacked PRs are open and green; rc6 remains the latest
published candidate and 4.2.6 the stable Gallery version. Public rule-path,
simplified-audit, and boxed privilege-comparison defects were reproduced
and fixed test-first. New descriptor, native-identity, audit-capability and
recursive-denial guards pass focused checks. Frozen full-suite coverage,
complete path explanations and the requested independent review follow.
The shared lab and remotes are unchanged. Decisions 21/22 and stable 5.0.0
remain gated; Decision 22 is proposed, not accepted.

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
- Final uninstrumented suite: 914 each, zero failed. Passed/skipped:
  elevated Desktop 890/24, Core 860/54; basic Desktop 749/165, Core 719/195.
  Frozen aggregate: 2,641/3,559 sequence (74.21%), 974/1,933 branches
  (50.39%); NTFSSecurity assembly 84.28%. All skipped templates have
  executed counterparts; mutations restored exactly before green builds.
- Live packaged candidate, 09:20 to 09:51 UTC: 330 passed, zero failed,
  two expected Server-module skips. Published rc6: 326 passed, four
  expected failures (Hidden and rc7 warning text in each edition), two
  skips. Tested folder and all 11 ZIP files are byte-identical.
- Temporary host result verifier failed on Desktop JSON wrapping/full
  test names; corrected verification passed on unchanged raw results in
  both editions. Cleanup wrapper's broad Error.Count was not acceptance
  proof. Independent probes verified all fixture objects/members/profiles
  gone from six machines. Raw failing markers and corrected evidence kept.
- One read-only independent code review approved, high confidence, no
  significant findings or confirmed exploit. Custom reviewer could not
  start (model unavailable); built-in code-review performed the one pass.
- Six checkpoints exist but report Standard, even after a successful
  temporary ProductionOnly probe; policy restored, no restore performed.
  Do not claim verified Production rollback evidence.
- Wider matrix not deployed: 13 Server 2025 VMs; Windows 11/2019/2022
  media present, OS detection cache empty. #34 has no reply since Oct 6.
- Full evidence: session artifact `quality-gate-3442194-20261009`;
  repository report `Tests/Lab/Acceptance-2026-10-09-quality-gate.md`.

## Next step

1. Finish Handoff 1: freeze Release source, prove characterization guards,
   run all four configurations, classify every refreshed gap and review.
2. Send code fixes and persistent evidence to gate 3 before publication;
   repeat affected packaged acceptance after integration. No local upload.
3. Retain stacked-PR order (15), obtain Decision 22 review, finish the OS
   matrix and obtain or explicitly accept #34 feedback through other gates.
4. Do not release stable 5.0.0 or equate a percentage with gate closure.
