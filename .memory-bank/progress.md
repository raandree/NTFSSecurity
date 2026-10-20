---
status: current
last-verified: 2026-10-19
owner: active-agent
source: repository and validation evidence
---

# Progress

## Current status

5.0.0-rc7 is published on the Gallery and GitHub (2026-10-10, tag at
`fa0701b`); rc6 is the one before it. On 2026-10-10 the maintainer merged the
whole stack into `master` (CI green): #116 (rc7), #120 (it replaced
#117, which GitHub closed unmerged when the branch deletion after #116 removed
its base), #118 (the quality-gate paths), #119 (the operating-system matrix
with three module fixes, Decision 24), and #121 (the Memory Bank). The
published rc7 passed its lab acceptance (gate 3) in the matrix and in the first
lab. On 2026-10-19 he merged #125 (Handoff 5) and #124 (Dependabot), and decided
the path to stable (Decision 21, "Closing the gate"). Stable Gallery version:
4.2.6.
After 5.0.0, archive in favor of WindowsAccessControl (Decision 18).

## Recent milestones

- 2026-10-02 to 2026-10-06: documentation/help aligned with source, CI and
  wiki moved to GitHub Actions, versioning/release automation established,
  and prereleases rc1 to rc4 published. Earlier detail is in git,
  `CHANGELOG.md`, `Docs/Version-History.md`, and Decisions 1 to 19.
- 2026-10-07: lab comparison of rc2/rc4 reproduced #34 over SMB and proved
  changed-section writes preserve the owner. Remote effective-access
  fallback returned no result; fixed test-first for rc5 (Decision 20).
- 2026-10-08: #114 merged (`fcb370e`), rc5 published and live-tested.
  Decision 21 established the quality gate. Corrected four-run coverage:
  rc5 58.1% sequence points/38.0% branches, not the initial one-run result.
- 2026-10-08: rc6 Phase 2 added basic-user CI, parameter-set/error tests,
  expanded domain/SMB cases, and fixes for privilege cleanup, path
  resolution, ownership retries, item conflicts, output equality, and
  inherited flags. Suite: 677; coverage 68.14% sequence/44.32% branches.
  Lab acceptance of `7b0781f` passed; two independent review passes.
- 2026-10-08: rc7 implemented proposed Decision 22, including breaking
  link binding/error changes, SimpleAccess traversal, cross-volume folder
  preservation, and named effective-access warnings. Suite: 712, no
  failures or test skipped everywhere. One review: no Blocker/Major.
  Lab candidate `dc6e9f5`: 326 passed, 2 skipped, cleanup verified.
- 2026-10-08: #115 merged (`b51d970`) and tagged rc6. Release run
  `37839669028` failed with HTTP 409 after Gallery publication. The log
  does not establish the previously assumed initial timeout/retry cause.
  Published rc6 live tests differed only in rc7's warning expectation.
- 2026-10-09: release attempt 2 succeeded; rc6 GitHub prerelease and zip
  appeared at 07:01:34 UTC. #116 passed CI on `d25647d`.
- 2026-10-09: autonomous follow-up on `ai/quality-gate-coverage` (#117, then
  #120), through `3442194`: 202 cases above rc7; fixed rooted result paths and
  the first-hidden-item omission; publication recovery verifies the exact
  SHA-512 identity, not merely the version. Suite: 914 per configuration, zero
  failures; 2,641/3,559 sequence points (74.21%), 974/1,933 branches (50.39%).
  Live comparison: candidate 330 passed, 0 failed, 2 expected skips (`7594e0c`).
- 2026-10-09: handoff 1 (#118): suite 914 to 1,310 per configuration, zero
  failures; 3,192/3,634 sequence points (87.84%), 1,273/1,978 branches; all 231
  unvisited methods classified (223 explained, 8 open). Eleven defects fixed,
  ten with a guard that is red before the fix and green after it (76 rows red
  at the base), among them a later command's exception that cmdlets swallowed
  (a `throw` made `Remove-Item2` remove the next item) and a privilege left
  enabled. Lab acceptance, `83149ee` against `f11ff41`: 486 passed, 0 failed, 2
  expected skips against 338 passed, 148 failed. Report in `Tests/Coverage`;
  record `Tests/Lab/Acceptance-2026-10-09-quality-gate-paths.md`.
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

## Stable capabilities

- 36 cmdlets: access, audit, inheritance, owners/descriptors, privileges,
  long-path items, links, hash, and disk space.
- Windows PowerShell 5.1 and PowerShell 7; RIPEMD160 and MACTripleDES are
  available only in Desktop. Both editions run elevated/basic-user in CI.
- Pester fixtures use `Tests/TestHelpers.psm1` TEMP sandboxes. Live tests
  are excluded from CI and run only on approved lab client/server targets.

## Open work

1. Decision 21 gate: the published rc7 is accepted in the matrix and the first
   lab (record); rc8 needs the same acceptance, and stable follows it
   (Decision 21, "Closing the gate"). Do not release 5.0.0 until the other
   gates close. Release steps:
   `Docs/Contributing/05-Releasing.md`; remove the prerelease label, date
   `[5.0.0]`, add the last prerelease to `$publishedVersions` (never the
   version of the manifest), tag through CI.
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
   pipeline parameters that no test binds by property name). Other open
   decisions: lazy path overloads, abandoned `PrivilegeEnabler`, dot patterns
   of `Get-ChildItem2 -Filter`, 17 owner-restore handlers that do not pass on
   what a later command raises (a rare combination), unused classes. No
   trigger for an audit write's ownership retry was found on a local volume or
   a Windows file server (probe of 48 calls) and no test reaches it. A
   conditional ACE display remains a .NET representation limit, not evidence
   of unconditional permissions.
8. Publication recovery (`95b827e`, merged in #120): 14 offline tests and exact
   artifact SHA-512 verification; the original upload errors remain errors for
   missing, different, or unverifiable outcomes. The agent published nothing,
   so the recovery has never run against the Gallery.
9. Operating-system matrix (Decision 24, accepted 2026-10-19): the lab and the
   cells exist and the published rc7 passes them (record). #34: the follow-up
   went up on 2026-10-19, no reply yet; the decision date is 2026-11-02.
10. Lab rollback evidence: new checkpoints report Standard even after a
    successful temporary ProductionOnly probe; original VM policy restored, no
    checkpoint restored. Don't represent them as verified Production snapshots.
