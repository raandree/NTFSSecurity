---
status: current
last-verified: 2026-11-11
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-11-11, 12:40 UTC: the maintainer merged #133 (the rc9 record,
09:42Z) and #134 (`ai/rc9-tests`, 10:21Z; CI on `master` green at `2c88ce7`)
and chose one more prerelease before the stable 5.0.0: `5.0.0-rc9a` (Decision
21, "Another prerelease before stable"). The label sorts after rc9:
NuGet.Versioning 6.9.1.3, the comparer of the Gallery and PSResourceGet, ranks
`5.0.0-rc10` below `5.0.0-rc9`. The module, the help file, and `Docs/Cmdlets`
equal the rc9 tag; the change is the label, `5.0.0-rc9` in
`$publishedVersions`, and the release notes: the note about #34 and the six
known limits, reviewed on `ai/release-5.0.0`, moved verbatim into
`[Unreleased]`, the notes of a prerelease. Branch `ai/release-5.0.0-rc9a`
(worktree `C:\Temp\ntfs-rc9a\release`) goes up with a pull request; the
maintainer merges it and pushes the tag. `ai/release-5.0.0` (`c7cad81`, local)
is superseded: it conflicts with rc9a in all three files.

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

rc9 contains (36 commits over `d0cb57c`, head `696ac38`): the five piped
parameters of `Add-` and `Remove-NTFSAccess` and `-NTFSAudit` are `object`,
converted in the cmdlet, so a typo for `Deny` no longer creates an Allow entry
and a list for `-AccessType` or `-AppliesTo` is rejected; the
`-SecurityDescriptor` sets report a failing descriptor and go on; the 17
owner-restore handlers pass
on what a later command raises; `Get-ChildItem2 -Filter` has one matcher with
the Windows PowerShell 5.1 rules; the library fixes 3.1 to 3.3 and 3.10;
`Get-NTFSOrphanedAccess` writes an error; `-SecurityDescriptor` of
`Set-NTFSSecurityDescriptor` at position 1; label `rc9`. The full suite on
`696ac38`: 2,162 cases in each CI configuration, 0 failed; two review rounds
(Decision 27, "Built in rc9") ended with "no finding" on `696ac38`. The
maintainer merged #131 (`823c814`) and #132 on 2026-10-22 and tagged
`5.0.0-rc9`; the Gallery has it since 08:50:59Z, and the identity check printed
`PUBLISHED_IDENTITY_VERIFIED` on 2026-10-22 and 2026-11-10. rc8
(tag `c719197`) and rc7 (tag `fa0701b`) were accepted on 2026-10-20 and
2026-10-10. The acceptance of the published rc9 with the live tests of rc7 and
rc8 came in four parts, after a host shutdown and a lost secure channel of
`OSWin11E`; it is recorded on `ai/acceptance-published-rc9`
(`Tests/Lab/Acceptance-2026-11-10-published-rc9.md`, merged as #133).

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

1. The rc9a pull request (`ai/release-5.0.0-rc9a`: `Prerelease = 'rc9a'`,
   `5.0.0-rc9` in `$publishedVersions`, the note and the limits in
   `[Unreleased]`): after its CI, he merges it with a merge commit and pushes
   the lightweight tag `5.0.0-rc9a` on the merge commit
   (`Docs/Contributing/05-Releasing.md`); the tag run publishes. Then
   `Test-PublishedRelease.ps1 -Version 5.0.0-rc9a`; `git diff --stat 5.0.0-rc9
   5.0.0-rc9a -- NTFSSecurity Security2 PrivilegeControl ProcessPrivileges Log`
   lists only `NTFSSecurity/NTFSSecurity.psd1` (the rebuilt DLL differs too;
   the build isn't byte-reproducible).
2. The acceptance of the published rc9a (new bytes, so the cells again): the
   identity check, the three cells and the first lab with the kit of the tag
   (case 11 is in it since #134), the module's suite in 24 runs, and the
   checks of both labs; about 1.5 hours (chains a1 and a2 of Handoff 6). The
   host stays on, and `OSWin11E` restarts right before the cells. A record
   under `Tests/Lab`; a defect that it finds needs another prerelease.
3. Then the stable pull request, made again from `master`: no `Prerelease`,
   `[Unreleased]` renamed to `## [5.0.0] - <tag day>` with a new empty
   `[Unreleased]` and the links (as on `ai/release-5.0.0`), and `5.0.0-rc9a`
   in `$publishedVersions`; merge, tag `5.0.0`, `Test-PublishedRelease.ps1
   -Version 5.0.0`, and the same diff check from `5.0.0-rc9a`.
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
