---
status: current
last-verified: 2026-10-21
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-10-22: 5.0.0-rc9 is published, the last prerelease before the
stable 5.0.0 (Decision 27). The maintainer merged #131 (`823c814`, 08:13Z; its
tree is byte-identical to the validated head `696ac38`) and the Memory Bank
#132 (`f2bcd9d`, 10:15Z), and pushed the lightweight tag `5.0.0-rc9` at
`823c814` at about 08:37Z. The CI run `39749188259` of the tag passed (Build
and test, then Release without an approval step) and the GitHub prerelease
appeared at 08:51:19Z. `Test-PublishedRelease.ps1` printed
`PUBLISHED_IDENTITY_VERIFIED` at 10:54Z and again inside the chain at 11:02Z
(the Gallery's SHA-512 matches the nupkg, the 11 module files are identical in
the nupkg and the zip, the manifest says `5.0.0-rc9`); the pathological-input,
`ToString`, and valid-shape probes give the results of the validated build on
the published bytes. The lab acceptance of the published bytes runs since
11:00:36Z in one detached chain (`Chain-Published.ps1 -Version 5.0.0-rc9 -Tag
rc9`, evidence `files\rc9\rc9-published` in the session folder, expected end
about 12:10Z, heartbeat every 10 minutes). rc8 (tag `c719197`) was accepted on
2026-10-20 (record `Tests/Lab/Acceptance-2026-10-20-published-rc8.md`, #128).

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

Open before the stable pull request: the end of the lab acceptance of the
published rc9 and its record (agent); his decision on #34 on 2026-11-02; his
check of `PSGALLERY_API_KEY`. The stable change then touches only the label,
the CHANGELOG, and `$publishedVersions` (add `5.0.0-rc9`; the list ends at rc8).

State at 2026-10-10: the maintainer integrated the release-gate stack into
`master` (#116, #120, #118, #119, #121; `fa0701b`, CI green; GitHub closed #117
unmerged when the branch deletion removed its base, Decision 15) and tagged rc7
(Gallery 12:30:57Z). The published rc7 passed its lab acceptance the same day
(record `Tests/Lab/Acceptance-2026-10-10-published-rc7.md`). The agent's
delegated decisions of 2026-10-09 and 10 are D1 to D47 in
`decisions-night-2026-10-09.md` of the session files; the maintainer accepted
Decisions 22 and 24 on 2026-10-19 and decides 23 on 2026-11-02.

## Evidence

- Evidence of rc9 is outside git, in the session folder
  `816cf47d-2f80-4eba-8ac9-41702c49560b\files\rc9`: the specs and review briefs,
  `suite-full1` (first integration), `suite-final` to `suite-final7-696ac38`
  (the head), the probes (`p-*.ps1`, `fixb-probe`, `shapes-r2`, `Run-Oracle.ps1`,
  `Run-Pathological.ps1`), the published rc8 (`rc8-published`), the published
  rc9 (`rc9-published-identity`: the nupkg, the zip, `Identity-5.0.0-rc9.json`;
  `oracle-published-rc9`), the chain of the acceptance (`rc9-published`: log
  `chain-published-rc9.log`, a stage folder and a result folder per stage), and
  the analyzer and surface results. The review probes of the reviewers are in
  `C:\Temp\ntfs-rc9\review*-probes-*` (temporary). The worktrees under
  `C:\Temp\ntfs-rc9` are temporary too.
- Milestones of earlier gates (rc6 and rc7 releases, handoff 1, the operating
  system matrix, handoff 5, the rc7 and rc8 acceptances) are in `progress.md`
  and in the records and reports under `Tests/Lab` and `Tests/Coverage`.
- Reviews: the custom `security-reviewer` can't start (its model is
  unavailable; no override); the built-in `code-review` agent reviewed the paths
  work, the matrix, rc8, and rc9; the built-in `security-review` agent found no
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

1. Lab acceptance of the published rc9: the chain started 2026-10-22 11:00:36Z
   (log `rc9-published\chain-published-rc9.log`; 68 minutes for rc8). When the
   log ends with `chain-published-rc9-DONE`, read the stage logs and the
   `Validate-LabResults.ps1` output, never the marker alone; save the machines
   again (`Save-VM`;
   `OSWin11E` is off after its hour); write
   `Tests/Lab/Acceptance-2026-10-22-published-rc9.md` and update this file,
   `progress.md`, and `deployment-notes.md` in one pull request (branch
   `ai/acceptance-published-rc9`; the maintainer pushes and merges). A defect
   that the chain finds needs rc10.
2. The stable pull request: no `Prerelease`, `## [5.0.0] - <date>` with an empty
   `[Unreleased]` and the links, and `5.0.0-rc9` in `$publishedVersions` (the
   list ends at rc8). The maintainer checks the expiry of `PSGALLERY_API_KEY`
   first, merges, and tags. Not before his decision on #34 (item 3).
3. #34 waits for a tester until 2026-11-02 (Decision 23, option 3; checklist:
   `Tests/Lab/Non-Windows-File-Server-Test.md`). On that date the maintainer
   chooses between waiting longer and accepting the untested risk with a
   release-note caveat. No agent can accept it.
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
