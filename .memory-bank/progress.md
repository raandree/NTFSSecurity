---
status: current
last-verified: 2026-11-13
owner: active-agent
source: repository and validation evidence
---

# Progress

## Current status

5.0.0 is the stable version on the Gallery and GitHub (2026-11-12, tag at
`bff4f61`; 4.2.6 before it). Its bytes passed the lab acceptance before they
were published, and the published package is the tested one (record
`Tests/Lab/Acceptance-2026-11-12-artifact-5.0.0.md`). The published rc7, rc8,
rc9, and rc9a passed their lab acceptance, rc9 and rc9a with the live tests
of case 11; 5.0.0 ships the code of rc9 and rc9a. Next: the archive in favor
of WindowsAccessControl (Decision 18).

## Recent milestones

- 2026-10-02 to 10: docs, help, CI, the wiki, and release automation; rc1 to
  rc6 (#114, #115); the quality gate (#117, #120, #118; Handoffs 2 to 4: eleven
  defects fixed, the matrix lab `NtfsSecurityOsMatrixLab`, three more found);
  the stack merged and rc7 tagged at `fa0701b` and accepted. Detail: git,
  `CHANGELOG.md`, Decisions 1 to 22, and the records of 2026-10-09 and 10 in
  `Tests/Lab`.
- 2026-10-10 to 19: Handoff 5, the coverage unknowns (#125): two `tr-TR`
  defects and the piped `AppliesTo` fixed test-first (Decision 26; report
  `Tests/Coverage/Quality-Gate-Unknowns-2026-10-10.md`). On 2026-10-19 #125
  and #124 merged, and the maintainer set the path to stable (Decision 21):
  Decisions 22 and 24 accepted, 23 option 3, rc8 with the fix of
  `GetEffectiveAccess`, and a tests-only round.
- 2026-10-20: rc8. The maintainer merged #126 and #127 (`c719197`: the fix of
  the swallowed initialization errors of `GetEffectiveAccess`, the hard-link
  limit in the pages, label `rc8`) and tagged `5.0.0-rc8` at about 10:28Z
  (Gallery 10:40:58Z, GitHub 10:41:07Z). Identity passed (10:42Z); the lab
  acceptance of the published bytes ran in one detached chain (68 minutes):
  three cells 1,374/0/12, the suite in 24 runs without a failure, the first lab
  245/0/1 per edition, every end state CLEAN. Record
  `Tests/Lab/Acceptance-2026-10-20-published-rc8.md` (#128).
- 2026-10-20: tests-only round (Decision 21; #129): 89 `It` blocks, the suite
  1,494 to 1,615 per configuration, 0 failed; 38 of 64 parameter sets closed,
  26 with a leftover; no defect (report
  `Tests/Coverage/Quality-Gate-Test-Round-2026-10-20.md`). On 2026-10-21 he
  merged #129 and #130; 24 lab runs passed. A probe then found that piped
  optional parameters ignore a bad value (a typo for Deny creates an Allow
  entry): Decision 27 sets the scope of rc9.
- 2026-10-21: rc9 built and reviewed (Decision 27; branch `ai/rc9`, head
  `696ac38`): four implementers worked test-first in worktrees; round 1 of
  the reviews found a Blocker and two Major findings, round 2 only Minor
  findings and Nits. Final suite: 2,162 cases per configuration, 0 failed in
  four configurations; both reviewers: no finding.
- 2026-10-22: rc9 published. The maintainer merged #131 (`823c814`; its tree
  equals the validated `696ac38`, and the runner's 2,162 cases per configuration
  equal the local run) and #132 (`f2bcd9d`) and tagged `823c814` (tag run
  `39749188259` passed without an approval step; GitHub 08:51:19Z). The identity
  check passed at 10:54Z (hashes: deployment notes). A planned shutdown of the
  host killed the first acceptance chain (11:00 to 11:14Z) after cell 1 of the
  matrix had passed (229/0/2 per edition).
- 2026-11-10: the lab acceptance of the published rc9 is complete (record
  `Tests/Lab/Acceptance-2026-11-10-published-rc9.md`, branch
  `ai/acceptance-published-rc9`). The second attempt (14:26:36Z, cold start of
  both labs) passed the suites and the first lab; the matrix stage stopped at
  the readiness of cell 1 (`OSWin11E`: `secure channel False`). A first rerun
  failed the same way ("Access is denied" for the lab account); the second
  rerun repaired the channel with `Test-ComputerSecureChannel -Repair` and the
  lab account and passed the three cells (1,374 / 0 / 12, CLEAN; both labs
  CLEAN at 16:03Z). He decided #34 (Decision 23, option 2: release with the
  caveat) and said that he checked `PSGALLERY_API_KEY`; the stable branch
  `ai/release-5.0.0` is prepared locally.
- 2026-11-10 to 11: Handoff 6, the focused scope (branch `ai/rc9-tests`, on the
  acceptance record). A review found criteria 2 to 4 of Decision 21 open for
  the final code, and the maintainer held the stable tag. No change to the
  module, the help file, or the manifest. The six known limits are in the
  `[5.0.0]` section of the CHANGELOG (`ai/release-5.0.0`). The C# coverage of
  `823c814` is measured in four configurations (3,666 of 4,074 sequence points
  with the tests of the tag; 3,672 of 4,074, 90.13%, with 52 new unit cases,
  the suite at 2,214 cases per configuration); the 169 unvisited methods (402
  points) are all classified by 35 rules, none open; criterion 2 by row: 417
  skipped rows, each executed in two other configurations (report
  `Tests/Coverage/Quality-Gate-rc9-2026-11-10.md`). Live case 11 (191 tests per
  edition) fails on the published rc8 in 79 tests, each for the documented
  reason, and passes on the published rc9 in the first lab (436 / 0 / 1 per
  edition) and in the three cells (2,520 / 0 / 12); the module's suite passed
  in 24 runs on six machine classes (1,911 cases per configuration, the host
  1,910); both labs CLEAN (addendum
  `Tests/Lab/Acceptance-2026-11-10-published-rc9-case-11.md`). The final unit
  suite on the tip passed in four configurations (2,214 cases each). The
  built-in `code-review` agent read the work three times: no problem in the
  tests; two Minor ones in the report; a probe gap and a missing cmdlet list in
  the release notes; and a stale commit count, wording that said more than the
  evidence, and unlisted probe files in the records (all fixed). No new product
  defect beyond the six accepted limits.
- 2026-11-11: the maintainer merged #133 (09:42Z) and #134 (10:21Z; CI on
  `master` green at `2c88ce7`) and chose one more prerelease before 5.0.0:
  `5.0.0-rc9a`, because NuGet.Versioning 6.9.1.3 (the comparer of the Gallery
  and PSResourceGet) ranks `5.0.0-rc10` below `5.0.0-rc9`. rc9's code and
  help; the note about #34 and the six known limits of `ai/release-5.0.0` moved
  verbatim into `[Unreleased]` (branch `ai/release-5.0.0-rc9a`), which
  supersedes `ai/release-5.0.0`.
- 2026-11-11: rc9a published (#135 `c135062`, tag run `43039152538`, Gallery
  14:42:14Z) and accepted from 16:29 to 17:51 UTC with the kit of its tag: three
  cells 2,520 / 0 / 12, first lab 436 / 0 / 1 per edition, suite 24 runs 0
  failed, every end state CLEAN; counts equal to rc9 with case 11 (record
  `Tests/Lab/Acceptance-2026-11-11-published-rc9a.md`).
- 2026-11-11 to 12: 5.0.0 published with the live proof of its bytes
  (Decision 21). #136 and #137 merged, a required reviewer on
  `powershell-gallery`, the tag `5.0.0` at `bff4f61`; GitHub lost its run in
  an Actions outage, and the manual run on the tag (CI #98) built the
  artifact. The lab passed it before the approval (11:45 to 13:07 UTC, every
  count equal to rc9a, every end state CLEAN); the Gallery has 5.0.0 since
  13:13:47Z, and its package is the tested nupkg. `Test-PublishedRelease.ps1`
  now accepts a manual run on the tag (record
  `Tests/Lab/Acceptance-2026-11-12-artifact-5.0.0.md`).
- 2026-11-13: #138 (the record of 5.0.0) merged at `75cb374`; CI #100 on
  `master` passed. The README shows status and statistics badges like the
  AutomatedLab README (`ai/readme-badges`, `bde8c9f`): CI of `master`, last
  commit, GitHub release, Gallery version, open issues, and downloads from
  GitHub and the Gallery. No CHANGELOG entry (Decision 7).

## Stable capabilities

- 36 cmdlets: access, audit, inheritance, owners/descriptors, privileges,
  long-path items, links, hash, and disk space.
- Windows PowerShell 5.1 and PowerShell 7; RIPEMD160 and MACTripleDES are
  available only in Desktop. Both editions run elevated/basic-user in CI.
- Pester fixtures use `Tests/TestHelpers.psm1` TEMP sandboxes. Live tests
  are excluded from CI and run only on approved lab client/server targets.

## Open work

1. Decision 21 gate: closed by the release. The published rc7, rc8, rc9, and
   rc9a and the artifact of 5.0.0 are accepted (records), rc9, rc9a, and 5.0.0
   with case 11; the record of 5.0.0 is merged (#138). Open: the maintainer's
   choice about the required reviewer of `powershell-gallery` and about
   adopting the acceptance of the artifact in
   `Docs/Contributing/05-Releasing.md`, and the stuck runs CI #94 to #97.
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
   cells exist, and the published rc7, rc8, rc9, and rc9a and the artifact of
   5.0.0 pass them (records). #34 is decided (Decision 23, option 2,
   2026-11-10): released with the caveat.
10. Lab rollback evidence: new checkpoints report Standard even after a
    successful temporary ProductionOnly probe; original VM policy restored, no
    checkpoint restored. Don't represent them as verified Production snapshots.
