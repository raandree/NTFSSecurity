---
status: current
last-verified: 2026-11-13
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

State at 2026-11-13: the maintainer merged #138, the record of 5.0.0
(`75cb374`; CI #100 on `master` passed). The README now shows status and
statistics badges like the AutomatedLab README (branch `ai/readme-badges`,
`bde8c9f`): the CI of `master` (the workflow `ci.yml`, not AppVeyor), the
last commit, the latest GitHub release and Gallery version, the open issues,
and the downloads from GitHub and the Gallery. Every badge rendered a live
value (2026-11-13: passing, v5.0.0, 10 open, 12k, 7.8M); no CHANGELOG entry
(Decision 7). The release state below is unchanged.

State at 2026-11-12, 13:30 UTC: 5.0.0 is published, and its bytes are proven
live. The maintainer merged #136 (the record of rc9a) and #137 (the stable
change: no `Prerelease`, `## [5.0.0] - 2026-11-11`, `5.0.0-rc9a` in
`$publishedVersions`), added himself as a required reviewer of the environment
`powershell-gallery`, and pushed the tag `5.0.0` at `bff4f61` on 2026-11-11 at
20:44:47Z. GitHub lost its run in an Actions outage (CI #97 and the runs of
the two merges, CI #94 to #96, stay queued without a job; cancel says
completed, rerun says running, delete is refused), so on 2026-11-12 he started
the workflow on the tag by hand (`gh workflow run ci.yml --ref 5.0.0`, CI #98,
run `43209324498`). Its job Release runs for any event on a tag ref; it waited
for the approval while the agent tested the artifact `packages` in the lab
(Decision 21, "Live proof of the stable bytes"): identity at 11:44:55Z, then
one detached driver from 11:45 to 13:07 UTC. Three cells 2,520 / 0 / 12, the
first lab 436 / 0 / 1 per edition, the suite in 24 runs 0 failed (1,911 cases
per configuration, the host 1,910; no skip differs from the host), every end
state CLEAN, every count equal to the published rc9a row for row, and every
log names the artifact's `NTFSSecurity.dll` (`217AA6AC…2234`). He approved;
the job Release published at 13:13:58Z (Gallery 13:13:47Z, GitHub 13:13:54Z;
warning: the CHANGELOG date is a day before the release). The Gallery serves
exactly the tested nupkg (SHA-256 `D9F387EF…A596`, its SHA-512 matches), and
the GitHub zip is the tested zip. `git diff --stat 5.0.0-rc9a 5.0.0` over the
module folders lists only the manifest.

`Test-PublishedRelease.ps1` of the tag looked only for the push run and
reported that the job Release didn't succeed; every other check passed. The
record branch `ai/acceptance-stable-5.0.0` (worktree
`C:\Temp\ntfs-stable\record`) fixes it (a manual run on the tag counts; the
newest run and attempt decide) and verifies 5.0.0 (PowerShell 7 and Windows
PowerShell 5.1) and rc9a again. It also carries the record
`Tests/Lab/Acceptance-2026-11-12-artifact-5.0.0.md` with four tables and a
Memory Bank update; the maintainer merged it as #138. The lab machines are
saved again, `OSWin11E` is off.

The earlier acceptances of published prereleases are rc7 (2026-10-10), rc8
(2026-10-20), rc9 (2026-11-10, with case 11 on 2026-11-11), and rc9a
(2026-11-11); see `progress.md` and `Tests/Lab`. Handoff 6 closed criteria 2
to 4 of Decision 21 for the code of rc9 (report
`Tests/Coverage/Quality-Gate-rc9-2026-11-10.md`); rc9a and 5.0.0 ship that
code unchanged, with the six known limits in the CHANGELOG.

## Evidence

- Session files of this work (`F`):
  `C:\Users\install\.copilot\session-state\f097ed24-a01f-4896-9c61-d1a0208cbdff\files`.
  `F\stable-acceptance` holds the run of the stable record (the artifact and
  `artifact-identity.json`, the driver log, the cells, the first lab, the
  suites, the checks, the tables, the identity check after the publication,
  and the package that the Gallery served); `F\rc9a-acceptance-2` the run of
  rc9a; `F\scripts` the helpers (`Prepare-ArtifactAcceptance.ps1`,
  `Run-ArtifactAcceptance.ps1`, `Run-PublishedAcceptance.ps1`,
  `Build-PublishedRecordTables.ps1`).
- Evidence of the release gate (`E`):
  `C:\Users\install\.copilot\session-state\816cf47d-2f80-4eba-8ac9-41702c49560b\files`.
  `E\qg-unknowns\scripts` holds the chain scripts (`Chain-Extended.ps1`,
  `Chain-SuiteOnly2.ps1`, `Repair-ClientChannel2.ps1`, and others; inspect
  before reuse); `E\rc9-coverage`, `E\qg-unknowns`, and `E\rc9` the evidence
  of Handoff 6 and of rc9, with manifests of SHA-256.
- The published hashes of every prerelease and of 5.0.0 are in the deployment
  notes; milestones of earlier gates are in `progress.md` and in the records
  and reports under `Tests/Lab` and `Tests/Coverage`.
- Reviews: the custom `security-reviewer` can't start (its model is
  unavailable); the built-in `code-review` agent reviewed the earlier work up
  to the stable change, and the built-in `security-review` agent found no
  exploitable vulnerability and two LOW items (Next step 6). The record branch
  of 5.0.0 hasn't had an independent review.
- Six checkpoints of the lab report Standard even after a successful
  ProductionOnly probe; policy restored, no restore performed: don't claim
  verified Production rollback evidence.

## Next step

1. The README badges (`ai/readme-badges`): he pushes the branch, opens the
   pull request, and merges it with a merge commit. The record of 5.0.0 is
   merged (#138).
2. His decisions after the release: keep or remove the required reviewer of
   `powershell-gallery` (while it stays, every tag run waits for an
   approval), and whether `Docs/Contributing/05-Releasing.md` adopts the
   acceptance of the artifact before the approval (it still accepts a stable
   release through the last prerelease).
3. The stuck runs CI #94 to #97: they hold nothing back; the force-cancel
   endpoint of the REST API or GitHub Support can remove them. The agent
   can't change runs (the house-rules hook).
4. The archive in favor of WindowsAccessControl (Decision 18) is the
   maintainer's.
5. Unchanged since the rc9 acceptance with case 11: what the lab can't show
   (ten of the 17 handlers that retry as the owner, the new
   `ReadSecurityError` of `Get-NTFSOrphanedAccess`, the changes that don't
   depend on where the item is), case 9 only in the first lab, no live cell
   for Windows 11 26H1, and no file server that isn't Windows (#34 caveat in
   the release notes; Decision 23, option 2).
6. Open housekeeping: keep or replace the matrix VMs (about 60 GB, saved
   between runs) and the evaluation client (it shuts down an hour after each
   start); the cleanup list before the archive (AppVeyor, Read the Docs,
   wiki, `test/transfer`, old checkpoints); the ACL of the stage folders under
   `C:\` in the lab kit (they inherit Authenticated Users: Modify; the second
   LOW finding of the security review), which needs a design change of the
   controller and a new acceptance; his confirmation of the explanations of
   the 169 methods (the report's open items).
