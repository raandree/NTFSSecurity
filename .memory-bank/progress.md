---
status: current
last-verified: 2026-10-21
owner: active-agent
source: repository and validation evidence
---

# Progress

## Current status

5.0.0-rc8 is published on the Gallery and GitHub (2026-10-20, tag at
`c719197`); rc7 (2026-10-10, tag at `fa0701b`) is the one before it. On
2026-10-10 the maintainer merged the stack of #116, #120, #118, #119, and #121
into `master` (CI green; the milestones have the details). On 2026-10-19 he
merged #125 (Handoff 5) and #124 (Dependabot) and decided the path to stable
(Decision 21, "Closing the gate"); on 2026-10-20 he merged #126 (the decisions)
and #127 (the rc8 fix and label) and tagged rc8; on 2026-10-21 he merged #128
(the rc8 record), #129 (tests), and #130 (this file). The published rc7 and
rc8 passed their lab acceptance in the matrix and in the first lab. rc9
(Decision 27) is built on the local branch `ai/rc9` and waits for his push,
pull request, merge, and tag. Stable Gallery version: 4.2.6. After 5.0.0,
archive in favor of WindowsAccessControl (Decision 18).

## Recent milestones

- 2026-10-02 to 2026-10-09: documentation and help aligned with the source, CI
  and wiki on GitHub Actions, release automation, and rc1 to rc6 published
  (rc5: the remote effective-access fallback, Decision 20; rc6 and the rc7
  candidate: Phase 2 and the behavior changes of Decision 22). #114 (`fcb370e`)
  and #115 (`b51d970`) merged. The rc6 release run failed with HTTP 409 after
  Gallery publication and attempt 2 succeeded (GitHub prerelease 2026-10-09
  07:01:34Z); the log does not establish the earlier assumed timeout cause.
  Detail: git, `CHANGELOG.md`, `Docs/Version-History.md`, Decisions 1 to 22.
- 2026-10-09: the autonomous follow-up (#117, then #120, through `3442194`) and
  handoff 1 (#118) took the suite from 202 cases above rc7 to 1,310 per
  configuration with zero failures and 3,192/3,634 sequence points (87.84%;
  74.21% before); publication recovery verifies the exact SHA-512 identity.
  Eleven defects were fixed, ten with a guard that is red before the fix (76
  rows red at the base), among them a later command's exception that cmdlets
  swallowed (a `throw` made `Remove-Item2` remove the next item) and a privilege
  left enabled. Lab acceptance, `83149ee` against `f11ff41`: 486 passed, 0
  failed against 338 passed, 148 failed. Report in `Tests/Coverage`; record
  `Tests/Lab/Acceptance-2026-10-09-quality-gate-paths.md`.
- 2026-10-09 to 10: handoffs 2 to 4 under the maintainer's delegation (decisions
  D1 to D47 in the night log of the session files). The matrix lab
  `NtfsSecurityOsMatrixLab` (Server 2019, 2022, 2025, a Windows 11 Enterprise
  22H2 client, Windows 11 26H1 suite only) found three module defects, fixed in
  `962887a` and `fdd7a8b`: audit inheritance by descriptor,
  `Get-NTFSEffectiveAccess -ServerName ''`, and the same cmdlet for a
  non-administrator on a domain member. The final candidate passes the module's
  suite on every machine (24 runs), the live controller in three cells (1,374
  passed, 0 failed, 12 skipped), and the first lab with case 9 (245 passed, 0
  failed, 1 skipped per edition). The Server 2022 effective-access failures
  were stale account state, not the module (the controller names the case-3
  account anew, `1dec389`). The built-in security review found no exploitable
  vulnerability and two LOW items left for the maintainer. Record:
  `Tests/Lab/Acceptance-2026-10-10-os-matrix.md`.
- 2026-10-10: the maintainer integrated the stack. His branch deletion after the
  merge of #116 (`8a6be9f`, 09:10:12Z) removed the base branch of #117, and
  GitHub closed #117 unmerged three seconds later instead of retargeting it
  (`cli/cli#14223` shows the same events); the earlier guidance that relied on a
  retarget was wrong. Nothing was lost: #120 (`bdb9981`, 10:50Z) replaced #117,
  then #118 (`03bef2c`, 11:12Z) and #119 (`fa0701b`, 11:28Z) merged after their
  retargeting; CI on `master` passed at 11:40Z. Decision 15 has the rule.
- 2026-10-10: rc7 published. The maintainer tagged `fa0701b` at about 12:20Z;
  the CI run of the tag passed and the Release job published without an
  approval step (Gallery 12:30:57Z, GitHub 12:31:09Z). The identity check
  (`Test-PublishedRelease.ps1`, 12:33Z) passed: Gallery SHA-512, nupkg and zip
  identical, manifest `5.0.0-rc7`. Hashes: deployment notes.
- 2026-10-10: gate 3 on the published rc7, 14:29 to 15:30 UTC, in one detached
  driver: the three matrix cells 1,374 passed, 0 failed, 12 skipped; the suite
  in 24 runs on six machine classes without a failure; the first lab with case
  9 245 / 0 / 1 per edition; every end state CLEAN. The counts equal those of
  the final local candidate. Record:
  `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`.
- 2026-10-10 to 2026-10-11: Handoff 5, the coverage unknowns (branch
  `ai/coverage-unknowns`, merged as #125 on 2026-10-19). rc7 measured at
  `fa0701b`: 3,198/3,649 sequence points; the live
  suite and the suite on a domain member add 9 sequence and 4 explicit branch
  points (`fdd7a8b`); two `tr-TR` defects fixed test-first (`419cfb3`;
  `0028ccd`, `fbe0289`, `8a625c8`); 101 `It` blocks added. The piped
  `AppliesTo` that a path dropped is fixed (`93ed2c7`, `9783d2a`, Decision 26)
  after three independent reviews and two checks: a carry-over of the scope
  between piped objects, and false sentences about empty values (`7bc7925`,
  `2112ee3`). Final `2112ee3`, product code built once at `9783d2a`: 1,492
  cases per configuration, 3,266/3,668 points. The labs accepted the package:
  first lab 245/0/1 per edition, the suite 1,189/0 in 16 configurations on
  four machines, three cells 229/0/2 per edition, every end state clean. Open:
  hard-link names under another root, the silent default scope of an
  unconvertible piped `AppliesTo`. Report:
  `Tests/Coverage/Quality-Gate-Unknowns-2026-10-10.md`.
- 2026-10-19: #125 (Handoff 5) and #124 merged, CI on `master` green. The
  maintainer decided the path to stable (Decision 21): Decisions 22 and 24
  accepted, 23 option 3 with the decision date 2026-11-02 (the #34 follow-up
  went up at 12:09 UTC), rc8 with the fix of `GetEffectiveAccess`, and a
  tests-only round for the plain test gaps until 2026-11-02.
- 2026-10-20: rc8. The maintainer merged #126 and #127 (`c719197`: the fix of
  the swallowed initialization errors of `GetEffectiveAccess`, the known limit
  of the hard-link cmdlets in the pages and the CHANGELOG, label `rc8`) and
  tagged `5.0.0-rc8` at about 10:28Z; Gallery 10:40:58Z, GitHub 10:41:07Z, no
  approval step. The identity check passed (10:42Z). The lab acceptance of the
  published bytes ran in one detached chain (68 minutes, 10:38 to 11:47Z, the
  saved machines restored first): three cells 1,374 passed, 0 failed, 12
  skipped; the suite in 24 runs without a failure (1,191 cases per
  configuration); the first lab 245/0/1 per edition; every end state CLEAN. A
  probe on four operating systems showed the boundary of the new error (a name
  of 32,718 characters). Record
  `Tests/Lab/Acceptance-2026-10-20-published-rc8.md` (#128).
- 2026-10-20: tests-only round (Decision 21). Four implementers, one
  `ParameterSets.*` test file each (#129): 89 `It` blocks, 121 cases, the
  suite 1,494 to 1,615 per configuration, 0 failed in four configurations; 38
  of 64 sets closed (7 before), 26 with a leftover (16 Limit, 7
  MaintainerDecision, 3 would-pin); no defect. Report:
  `Tests/Coverage/Quality-Gate-Test-Round-2026-10-20.md`. On 2026-10-21 he
  merged #129 (08:24Z) and #130 (08:47Z); the new tests passed in three CI
  runs and in 24 lab runs on six machine classes (0 failed). A probe then
  found that piped optional parameters ignore a bad value (a typo for Deny
  creates an Allow entry); Decision 27 sets the scope of rc9, the designs were
  chosen on 2026-10-21, and four work items started (branch
  `ai/rc9-before-stable`).
- 2026-10-21: rc9 built and reviewed (Decision 27; branch `ai/rc9`, 36 commits
  over `d0cb57c`, head `696ac38`, local until he pushes). Four implementers
  worked test-first in worktrees (the five piped parameters, the 17 handlers
  and three inconsistencies, the library items, the filter); the chains were
  cherry-picked in order, so every fix sits in the commit of its item. Round 1
  (three read-only reviewers) found a Blocker (the last-dot rule of the
  filter) and two Major findings (a named `$null`; a blank value of the other
  parameter group, documented); round 2 (two reviewers, five checks) found
  only Minor findings and Nits, among them completers that were not culture
  invariant (`tr-TR`) and a list for `-AccessType` or `-AppliesTo`, which
  PowerShell combines bit by bit; he chose to reject it. Final suite on
  `696ac38`: 2,162 cases per configuration, 0 failed in four configurations
  (rc8: 1,615); docs fixpoint; analyzer clean; valid shapes differ from rc8 in
  9 list rows only; both reviewers: no finding.

## Stable capabilities

- 36 cmdlets: access, audit, inheritance, owners/descriptors, privileges,
  long-path items, links, hash, and disk space.
- Windows PowerShell 5.1 and PowerShell 7; RIPEMD160 and MACTripleDES are
  available only in Desktop. Both editions run elevated/basic-user in CI.
- Pester fixtures use `Tests/TestHelpers.psm1` TEMP sandboxes. Live tests
  are excluded from CI and run only on approved lab client/server targets.

## Open work

1. Decision 21 gate: the published rc7 and rc8 are accepted in the matrix and
   the first lab (records); stable follows rc9 (Decision 27): after his push,
   pull request, merge, and tag of rc9 the agent runs the lab acceptance of
   the published bytes (about 70 minutes). Do not release 5.0.0 until the other
   gates close: that acceptance, the decision on #34 on 2026-11-02, and the key
   check. Release steps: `Docs/Contributing/05-Releasing.md`; remove the
   prerelease label, date `[5.0.0]`, add the last prerelease (rc9) to
   `$publishedVersions` (never the version of the manifest), tag through CI.
2. Issues: #110's seven items were addressed by rc6, but #115 deliberately
   used no closing keyword. #34 stays open for non-Windows owner feedback
   or maintainer acceptance. #16, #21, #45, #89 await reporters. #68 tracks
   ShouldProcess for security cmdlets; enhancements #22/#49/#68/#77/#87
   are not planned for 5.0.0. Labels follow Decision 17.
3. Deferred reviews (not silently accepted): rc3 extra DACL read/SDDL
   snapshots/duplicate SACL check; rc4 findings listed in #113, including
   library-only RemoveAll account filters; rc5 unchecked Authz errors and
   lab-controller hardening; rc6 failed privilege-disable retry (not
   reproduced); rc7 audit missing-path error IDs declined in Decision 22.
4. Architecture/cmdlet design: Decision 22 is accepted (2026-10-19); two link
   changes are breaking. Keep unused classes/helper overloads until a
   maintainer decision; do not remove them to improve coverage percentages.
5. ARM64 workstation: out of scope (maintainer, 2026-10-11, Decision 25).
6. Optional maintainer cleanup: obsolete AppVeyor/Read the Docs access,
   wiki editing restrictions, `test/transfer`, and old lab checkpoints
   when no longer needed. No remote changes or snapshot restores here.
7. Remaining-path inventory at the final measured commit of Handoff 5
   (`2112ee3`): 402 unvisited sequence points in 183 methods, all classified
   (`Tests/Coverage`): 167 explained from source with evidence, 16 open (8:
   `FileSecurity` conversions, `RemoveAll` account filters; 8 getters of
   pipeline parameters that no test binds by property name). Decision 27: rc9
   fixes the conversions, `RemoveAll`, the lazy overloads, the dot patterns,
   and the 17 handlers; `PrivilegeEnabler` and unused classes stay. No
   trigger for an audit write's ownership retry was found on a local volume or
   a Windows file server (probe of 48 calls) and no test reaches it. A
   conditional ACE display remains a .NET representation limit, not evidence
   of unconditional permissions.
8. Publication recovery (`95b827e`, merged in #120): 14 offline tests and exact
   artifact SHA-512 verification; the original upload errors remain errors for
   missing, different, or unverifiable outcomes. The agent published nothing,
   so the recovery has never run against the Gallery.
9. Operating-system matrix (Decision 24, accepted 2026-10-19): the lab and the
   cells exist and the published rc7 and rc8 pass them (records). #34: the
   follow-up went up on 2026-10-19, no reply yet; the decision date is
   2026-11-02.
10. Lab rollback evidence: new checkpoints report Standard even after a
    successful temporary ProductionOnly probe; original VM policy restored, no
    checkpoint restored. Don't represent them as verified Production snapshots.
