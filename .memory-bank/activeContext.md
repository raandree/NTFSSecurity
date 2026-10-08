---
status: current
last-verified: 2026-10-08
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

The behavior changes that Phase 2 of the quality gate found (Decision 16)
are decided as assumptions for the maintainer's review (Decision 22) and
implemented test-first on the local branch `ai/release-5.0.0-rc7`, stacked
on #115 (5.0.0-rc6, head `be04cb7`, CI green, not merged yet). The
maintainer reviews the choices, merges #115 and tags 5.0.0-rc6, and
publishes the branch as 5.0.0-rc7. Then Phase 3 and 5.0.0; after 5.0.0
the repository is archived in favor of WindowsAccessControl (Decision 18).

## Evidence

- 2026-10-08, `ai/release-5.0.0-rc7`, 11 commits on `be04cb7` (`3899228`
  to `1063b29`) and two commits of records:
  - Decision 22: items 1, 2, 5, 6, 7, and 8 changed, 7 and 8 breaking (the
    link cmdlets require `-Path` and `-Target` and write non-terminating
    errors); items 3, 4, 9, and 10 kept, 9 with an FAQ entry. New defects,
    fixed with a regression test that failed first: `Move-Item2` deleted
    an empty folder that it moved to another volume (AlphaFS emulated the
    move); the link cmdlets failed with `GetDefaultValueFailed` for every
    piped object; `Get-NTFSSimpleAccess` failed for a folder that came
    after its parent folder a second time.
  - One `security-reviewer` pass over `be04cb7..4ee01e5`: no Blocker or
    Major. Minor 1 to 5 and Nits 7 to 9 fixed test-first in `7936d9f` to
    `1063b29`; Nit 7, the warning of `Get-NTFSEffectiveAccess` for names
    of this computer, was reproduced first. Nit 6 declined (Decision 22).
  - Suite of `1063b29`: 712 tests. Elevated: 688 passed and 24 skipped in
    Windows PowerShell 5.1, 658 and 54 in PowerShell 7. As a basic user:
    612 and 100, 582 and 130. No failure, none skipped in all four.
  - Lab acceptance of `dc6e9f5` after the checkpoint
    `ntfs-rc7-dc6e9f5-before-acceptance`, 16:24 to 16:40 UTC: 326 tests in
    both editions, none failed, 2 skipped as in rc6
    (`Tests/Lab/Acceptance-2026-10-08-5.0.0-rc7.md`). The code of
    `4ee01e5` and a first run of `dc6e9f5` without the checkpoint had the
    same counts. The fixture was removed at 16:21 and 16:44 UTC, and its
    removal checked each time.
- #115 passed CI in all four configurations on `be04cb7`, with the first
  runs of `Invoke-TestsAsBasicUser.ps1` on GitHub runners.
- #34: no reply from the tester since 2026-10-06.

## Next step

1. The maintainer reviews the choices of Decision 22, each its own commit,
   above all the two breaking changes of the link cmdlets.
2. He pushes the branch and opens its pull request with the base
   `ai/release-5.0.0-rc6`; after #115 is merged and tagged, he changes the
   base to `master`, merges with a merge commit (Decision 15), and tags
   `5.0.0-rc7`. The live tests then run against the published package
   (`-Version 5.0.0-rc7`).
3. He decides the scope of Phase 3: the operating systems, the code that
   nothing calls, and file servers that aren't Windows (#34).
