---
status: current
last-verified: 2026-10-09
owner: active-agent
source: repository and validation evidence
---

# Progress

## Current status

5.0.0-rc6 is published on the Gallery and GitHub; its failed Release job
recovered in attempt 2 on 2026-10-09. #116 (rc7, `d25647d`, base `master`)
is open and green, not merged or published. Further quality-gate work is
local on `ai/quality-gate-coverage`; Phase 2 is not complete while the
remaining-path inventory is open. Stable Gallery version: 4.2.6.
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
- 2026-10-09: autonomous follow-up on `ai/quality-gate-coverage`, through
  `3442194`, adds 202 cases above rc7: deletion/owner failures, all 13
  scopes, inheritance transitions, enumeration, forced replacement,
  descriptor failures, and offline CI recovery. Reproduced/fixed rooted
  result-path handling and first-hidden-item omission. Publication recovery
  verifies exact SHA-512 identity, not merely version existence.
- 2026-10-09: final uninstrumented suite: 914 per configuration, zero
  failures; coverage: 2,641/3,559 sequence points (74.21%) and 974/1,933
  branches (50.39%), aggregate of four runs without AltCover `--save`.
  All skipped templates have executed counterparts. Mutation guards were
  proved and production source restored; Release build/checks pass.
- 2026-10-09: live comparison, 09:20 to 09:51 UTC: candidate 330 passed,
  zero failed, two expected skips; published rc6 four expected Hidden/
  warning-text failures only. Independent cleanup probes verified fixture
  absence; raw host-verifier failures retained with corrected verification.
  Lab guards/acceptance committed in `7594e0c`. One independent code review
  approved with no significant finding (custom model unavailable; built-in
  fallback). All 11 tested files match the ZIP. OS/path gates stay open.

## Stable capabilities

- 36 cmdlets: access, audit, inheritance, owners/descriptors, privileges,
  long-path items, links, hash, and disk space.
- Windows PowerShell 5.1 and PowerShell 7; RIPEMD160 and MACTripleDES are
  available only in Desktop. Both editions run elevated/basic-user in CI.
- Pester fixtures use `Tests/TestHelpers.psm1` TEMP sandboxes. Live tests
  are excluded from CI and run only on approved lab client/server targets.

## Open work

1. Decision 21 gate: review Decision 22, integrate reviewed quality-gate
   follow-up, publish the next candidate, and test the published package.
   Do not release 5.0.0 until the remaining-path and OS-matrix gates close.
   Release steps: `Docs/Contributing/05-Releasing.md`; remove prerelease
   label, date `[5.0.0]`, update `$publishedVersions`, tag through CI.
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
4. Architecture/cmdlet design: Decision 22 remains proposed; two link
   changes are breaking. Keep unused classes/helper overloads until a
   maintainer decision; do not remove them to improve coverage percentages.
5. ARM64 workstation: PowerShell 7.6.1 crashed under x64 emulation without
   module frames; native-x64 CI did not reproduce it.
6. Optional maintainer cleanup: obsolete AppVeyor/Read the Docs access,
   wiki editing restrictions, `test/transfer`, and old lab checkpoints
   when no longer needed. No remote changes or snapshot restores here.
7. Fresh coverage inventory at `3442194`: 918 unvisited sequence points.
   Of these, 244 are in classes unused by cmdlets and 112 in parameter
   getters; 562 remain for finer review/testing, including unused overloads,
   defensive/native failures, and environment-specific branches. High-value
   local gaps closed: folders/Force/DeleteError, RestoreOwnerError, all
   scopes, file/folder inheritance, enumeration/depth/link skipping,
   descriptor write failures, and forced file replacement. Remaining
   candidates: audit ownership-retry failures, SD inheritance edge cases,
   effective-access unresolved identity, recursive denial/error surfaces,
   output-object comparisons/formatting. A conditional ACE display remains
   a .NET representation limit, not evidence of unconditional permissions.
8. Publication recovery is implemented locally in `95b827e`, with 14 offline
   tests and exact artifact SHA-512 verification. Original upload errors
   remain errors for missing/different/unverifiable outcomes. Not deployed
   until the maintainer merges/pushes; no publication was performed here.
9. Phase 3: choose OS scope (proposed Windows 11 client/2019/2022 servers),
   detect ISO editions, provision without repurposing shared VMs, then run
   published-package acceptance. #34 has no new reply since 2026-10-06.
10. Lab rollback evidence: new checkpoints exist but report Standard even
    after a successful temporary ProductionOnly probe. Classification is
    unresolved; original VM policy restored, no checkpoint restored. Do
    not represent these as verified Production snapshots.
