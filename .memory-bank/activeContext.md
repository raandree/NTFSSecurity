---
status: current
last-verified: 2026-11-10
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-11-10, evening: the maintainer holds the stable 5.0.0 tag. A
review in another chat (Handoff 6) found three of the five exit criteria of
Decision 21 open for the final code, and I checked each against our records:
criterion 3 (the C# coverage was last measured on 2026-10-11; 33 C# product
files changed since, 35 files in rc9), criterion 4 (the known limits of Decision
27 are not in the release notes), and criterion 2 (no test skipped in every
configuration, not checked by row for the new tests). The live tests are the
same Git blob since rc7 and don't exercise the rc9 changes. He chose the
focused scope and accepted and listed every known limit, none fixed in an rc10.
The work is on `ai/rc9-tests` (worktree `C:\Temp\ntfs-rc9\tests`, stacked on the
record): list the limits (done: `204dbb6` on `ai/release-5.0.0`); measure the
coverage of `823c814`, classify the unvisited points of the changed files, test
the reachable gaps, re-measure, check the skips by row; add a time-boxed live
case 11; prove that it fails on the published rc8; accept the published rc9
again with the extended kit. Stop rule: a defect is reproduced on rc9, and he
chooses rc10 or accept-and-list; the module, the help file, and the manifest
stay as they are until then. The measurement chain of the coverage is
`files\rc9-coverage\m1` in the session folder (`Chain-Coverage.ps1`).

Earlier on 2026-11-10: the lab acceptance of the published 5.0.0-rc9 is complete,
and its record is committed on `ai/acceptance-published-rc9`
(`Tests/Lab/Acceptance-2026-11-10-published-rc9.md` with four tables; the
maintainer pushes and merges). rc9 is the last prerelease before the stable
5.0.0 (Decision 27). The maintainer merged #131 (`823c814`; its tree equals the
validated head `696ac38`) and the Memory Bank #132 on 2026-10-22 and tagged
`5.0.0-rc9` at `823c814`; the tag run `39749188259` passed (Gallery
08:50:59Z, GitHub 08:51:19Z), and `Test-PublishedRelease.ps1` printed
`PUBLISHED_IDENTITY_VERIFIED` on 2026-10-22 and again on 2026-11-10 (14:27Z).
The acceptance came in four parts. A planned shutdown of the host (System event
1074, 2026-10-22 11:14:36Z) killed the first attempt after cell 1 had passed.
The second attempt (2026-11-10 from 14:26:36Z, cold start of both labs) passed
the six suites (24 runs, 0 failed; 1,859 cases per configuration, 1,858 on the
host) and the first lab (245 passed, 0 failed, 1 skipped per edition, CLEAN),
but `OSWin11E` lost its secure channel after the cold start, so no cell ran.
The first rerun failed at the same check (the lab account got "Access is
denied" while a session of the local account still said True). The second rerun
(15:36:36Z) repaired the channel with `Test-ComputerSecureChannel -Repair` and
the lab account, judged it by a session of the lab account, and passed the
three cells (229 / 0 / 2 per edition and cell, 1,374 / 0 / 12 in all; CLEAN).
Both labs were CLEAN at 16:03Z, and the 18 machines other than `OSWin11E` were
saved again at 16:10Z. The record names the deviations (suites before the
cells; cell 1 on the accounts of the interrupted fixture). The outputs of the
pathological-input probe on the published bytes weren't kept. rc8 (tag
`c719197`) was accepted on 2026-10-20 (record
`Tests/Lab/Acceptance-2026-10-20-published-rc8.md`, #128).

rc9 contains (36 commits over `d0cb57c`, head `696ac38`): the five piped parameters of `Add-` and
`Remove-NTFSAccess` and `-NTFSAudit` are `object`, converted in the cmdlet
(`ParameterConversion`), so a typo for `Deny` no longer creates an Allow entry;
a list for `-AccessType` and `-AppliesTo` is rejected; the `-SecurityDescriptor`
sets report a failing descriptor and go on; the 17 owner-restore handlers pass
on what a later command raises; `Get-ChildItem2 -Filter` has one matcher with
the Windows PowerShell 5.1 rules; the library fixes 3.1 to 3.3 and 3.10;
`Get-NTFSOrphanedAccess` writes an error; `-SecurityDescriptor` of
`Set-NTFSSecurityDescriptor` at position 1; tests that bind four parameters by
property name; label `rc9`.

Validation of `696ac38`: the full suite in the four CI configurations, 2,162
cases each, 0 failed (rc8: 1,615; skipped 27, 359, 58, and 390, so every new
case runs where it can); the pages and the help file are a fixpoint (0 drift, 0
broken links; the help file is identical after a second generation);
PSScriptAnalyzer reports nothing in the 11 changed scripts; the public surface
differs from rc8 by 16 `object` properties, 5 completer classes, 1 protected
method, and 1 parameter position, and equals the candidate of round 1; a
matrix of valid shapes of the five parameters, run on the published rc8 and on
this build in both editions, differs in exactly the 9 list rows of
`Add-NTFSAccess`. Two review rounds (Decision 27, "Built in rc9"): round 1 on the
first integration found a Blocker (the last-dot rule of the filter) and two
Major findings; round 2 on the final tree and five checks of its fixes found
only Minor findings and Nits (wrong statements in the pages, completers that
were not culture invariant, the list for `-AccessType` and `-AppliesTo`, ways
around that rejection, a collection that holds itself, a message formatter that
threw, an enumerator that fails in `Dispose`); all are fixed with a test that
is red without the fix, or decided, and both reviewers closed their last
findings with "no finding" on `696ac38`. A collection that holds itself still
ends the host through the three flags parameters, as in rc8 (known limit). A
blank, `$null`, or `DBNull` value of the other parameter group is
`AmbiguousParameterSet` (documented, not restructured).

Open before the stable pull request: the maintainer merges the acceptance
record of rc9 (the agent's part is done). Two gates closed on 2026-11-10, in
answer to an explicit question: he accepts the untested risk of #34 (Decision
23, option 2: release 5.0.0 with the caveat) and says that he checked
`PSGALLERY_API_KEY` (valid, not expiring soon; the key is a secret that the
agent cannot read, and nothing about it is recorded here). The stable change
touches only the label, the CHANGELOG (with the caveat), and `$publishedVersions`
(add `5.0.0-rc9`; the list ends at rc8).

State at 2026-10-10: the maintainer integrated the release-gate stack into
`master` (#116, #120, #118, #119, #121; `fa0701b`, CI green; GitHub closed #117
unmerged when the branch deletion removed its base, Decision 15) and tagged rc7
(Gallery 12:30:57Z). The published rc7 passed its lab acceptance the same day
(record `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`). The agent's
delegated decisions of 2026-10-09 and 10 are D1 to D47 in
`decisions-night-2026-10-09.md` of the session files; the maintainer accepted
Decisions 22 and 24 on 2026-10-19 and decided 23 on 2026-11-10 (option 2).

## Evidence

- Evidence of rc9 is outside git, in the session folder
  `816cf47d-2f80-4eba-8ac9-41702c49560b\files\rc9`: the specs and review briefs,
  `suite-full1` (first integration), `suite-final` to `suite-final7-696ac38`
  (the head), the probes (`p-*.ps1`, `fixb-probe`, `shapes-r2`, `Run-Oracle.ps1`,
  `Run-Pathological.ps1`), the published rc8 (`rc8-published`), the published
  rc9 (`rc9-published-identity`: the nupkg, the zip, `Identity-5.0.0-rc9.json`;
  `oracle-published-rc9`), the acceptance (`rc9-published`: the first attempt;
  `rc9-published-2`: the second attempt and the reruns, with the log
  `chain-published-rc9.log`, a stage folder per stage, `live-matrix-rc9n`,
  `live-rc9`, `localsuite-rc9`, `tables`; `evidence-manifest.csv` lists the 618
  files), and the analyzer and surface results. The helper scripts of the
  acceptance (the driver, the restore, the checks, `Rerun-Matrix.ps1`,
  `Repair-ClientChannel2.ps1`, `Build-RecordTables2.ps1`) are in
  `files\qg-unknowns\scripts`. The review probes of the reviewers are in
  `C:\Temp\ntfs-rc9\review*-probes-*` (temporary). The worktrees under
  `C:\Temp\ntfs-rc9` are temporary too.
- Milestones of earlier gates (rc6 and rc7 releases, handoff 1, the operating
  system matrix, handoff 5, the rc7 and rc8 acceptances) are in `progress.md`
  and in the records and reports under `Tests/Lab` and `Tests/Coverage`.
- Reviews: the custom `security-reviewer` can't start (its model is
  unavailable; no override); the built-in `code-review` agent reviewed the paths
  work, the matrix, rc8, rc9, and (2026-11-10, "no finding") the stable change;
  the built-in `security-review` agent found no
  exploitable vulnerability and two LOW items for the maintainer (Next step 5).
- Raw evidence of the older gates is outside git: the session folder
  `4b12e2f4-d4c7-4a5d-883a-ddb7421c4848\files` (`qg-paths`, the matrix runs, the
  night log), `26f151b6-e46f-49bd-9398-b27e20603949\files\quality-gate-3442194-20261009`,
  and `816cf47d-2f80-4eba-8ac9-41702c49560b\files\qg-unknowns` (430 files of
  `rc8-published`, with a manifest; the published hashes are in the deployment
  notes).
- Six checkpoints of the lab report Standard even after a successful
  ProductionOnly probe; policy restored, no restore performed: don't claim
  verified Production rollback evidence.

## Next step

1. The acceptance record of rc9 (branch `ai/acceptance-published-rc9`: the
   record `Tests/Lab/Acceptance-2026-11-10-published-rc9.md` with four tables,
   and the Memory Bank): the maintainer pushes it and merges it with a merge
   commit first; it stays valid, and `ai/rc9-tests` stacks on it (Decision 15).
2. The stable pull request (branch `ai/release-5.0.0`, local, three commits;
   `204dbb6` lists the known limits; the review of `6715b82` found nothing, and
   the delta of `204dbb6` is reviewed at the end; the body draft is
   `C:\Temp\ntfs-rc9\final-msgs\pr-stable-body.md`): no `Prerelease`,
   `## [5.0.0] - <date>` with the caveat of #34, an empty `[Unreleased]`, the
   links, and `5.0.0-rc9` in `$publishedVersions`. It opens only after the
   program above, and its date is set to the day of the tag (the Release job
   only warns about a different day). After the release, run
   `Test-PublishedRelease.ps1 -Version 5.0.0`; the module sources must differ
   from rc9 only in the manifest: `git diff --stat 5.0.0-rc9 5.0.0 --
   NTFSSecurity Security2 PrivilegeControl ProcessPrivileges Log` lists only
   `NTFSSecurity/NTFSSecurity.psd1` (the rebuilt DLL differs too; the build
   isn't byte-reproducible). A defect that a later run finds needs rc10.
3. #34: decided on 2026-11-10 (Decision 23, option 2; see the first paragraph
   of this section). The issue has no comment since 2026-10-19 and no tester
   result. The caveat names the file servers that the matrix tested (Windows
   Server 2019, 2022, 2025) and says where to report after the archive.
4. Open housekeeping: keep or replace the matrix VMs (about 60 GB, saved between
   runs) and the evaluation client (it shuts down every hour; `OSWin11E` is
   off); a domain cell for Windows 11 26H1, whose client loses the secure
   channel to the Server 2025 domain controller; the cleanup list before the
   archive (AppVeyor, Read the Docs, wiki, `test/transfer`, old checkpoints) is
   the maintainer's. The tests-round report still says that the new tests "have
   not run on Windows Server 2019/2022/Windows 11"; the 24 lab runs of
   2026-10-21 changed that (fix in a later documentation pull request).
5. Of the two LOW findings of the security review, the swallowed initialization
   errors of `GetEffectiveAccess` are fixed in rc8; he still decides the other:
   the ACL of the stage folders under `C:\` in the lab kit (they inherit
   Authenticated Users: Modify; protecting them is a design change of the
   controller and needs a new acceptance).
6. Known limits after rc9, for the archive (Decision 27): `Get-FileHash2
   -Algorithm` keeps the silent default for a piped value that does not convert;
   three settings still read their value with an unchecked cast;
   `PrivilegeEnabler` is not disposed in some paths; `Get-NTFSEffectiveAccess`
   fails with an `ArgumentOutOfRangeException` on a FAT32 volume or an item with
   a NULL DACL (older than rc9); 9 of the 17 owner-restore handlers and the
   error branch of `Get-NTFSOrphanedAccess` cannot be pinned by a test.
7. Do not release stable 5.0.0 or equate a percentage with gate closure.
