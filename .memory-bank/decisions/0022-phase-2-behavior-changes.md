---
status: proposed
date: 2026-10-08
last-verified: 2026-10-09
owner: shared
source: agent choices in autopilot on 2026-10-08, for the maintainer's review; confirmed by the agent under his delegation on 2026-10-09
---

# Decision 22: The behavior changes of Phase 2

- Context: Decision 16 left the behavior changes that Phase 2 found to the
  maintainer (`progress.md`, open work 4). On 2026-10-08 he asked to work
  on them while the pull request of 5.0.0-rc6 (#115) built, in autopilot;
  the agent took the recommended option for each. Every choice is an
  assumption for his review. Each change is its own commit on
  `ai/release-5.0.0-rc7` (`3899228` to `4ee01e5`, the label in `d17e0f7`,
  the review fixes in `7936d9f` to `1063b29`). A revert can conflict where
  a later commit touched the same page or test, and then needs the help
  file generated again.
- Choices:

| # | Item | Choice |
| --- | --- | --- |
| 1 | `Get-NTFSOrphanedAudit` returned nothing without the Security privilege | Changed: `ReadSecurityError`, like `Get-NTFSAudit`; a missing path keeps `ReadError` |
| 2 | `Get-NTFSSimpleAccess` left out a folder whose parent it hadn't reported | Fixed: such a folder, also a drive root, gets all entries; a repeated folder no longer fails with `ReadError` |
| 3 | Developer Mode for `New-NTFSSymbolicLink` | Kept as documented: new P/Invoke and fallback code before the archive (Decision 18) |
| 4 | `-WhatIf` names a conflict in a verbose message, not a warning (R7) | Kept, as for #108 and the missing destination folder |
| 5 | The fallback warning of `Get-NTFSEffectiveAccess` didn't name the server | Changed: it names the computer |
| 6 | `Move-Item2` can't move a folder to another volume | Kept the refusal; fixed what was found: with `CopyAllowed`, AlphaFS copied and deleted folders and lost empty ones. Now a `MoveError` that names folder and destination |
| 7 | The link cmdlets stopped with terminating errors | **Breaking:** a non-terminating error per link, and the next link |
| 8 | `-Path` and `-Target` of the link cmdlets were optional | **Breaking:** required. An omitted `-Path` failed with an index error, an omitted `-Target` meant the current location |
| 9 | Entries and descriptors are equal only as the same .NET object | Kept the equality of .NET; the FAQ shows `Compare-Object -Property` |
| 10 | `Copy-Item2` doesn't create the missing destination folders (rc6) | Kept, like `Copy-Item` and `Move-Item2` |

- Found on the way and fixed: every object piped to the link cmdlets
  failed with `GetDefaultValueFailed` (item 8). Item 6 is not the cause of
  #21, whose report used `-Force` within one volume.
- Review: one `security-reviewer` pass over `be04cb7..4ee01e5` found no
  Blocker or Major issue. Fixed test-first: the link cmdlets stopped for a
  path with an invalid character in Windows PowerShell, named no path in
  some errors, and checked `-Path` and `-Target` in different orders;
  `Get-NTFSEffectiveAccess` warned for every name of this computer except
  `localhost` in lowercase (reproduced, Decision 16); the tests of the
  case-insensitive parent lookup and of a drive root, and the shared
  administrative-share helpers. Declined: one error ID for a missing path
  in the audit cmdlets (`ReadError` and `ReadFileError`), a change of
  behavior for scripts that check the ID.
- Rationale: an error instead of a result that looks valid (1, 2, 6);
  per-item errors, as in the other cmdlets (7); no silent default for a
  path that creates something (8); no new features before the archive
  (3); the conventions of .NET and PowerShell (4, 9, 10).
- Open: the maintainer accepts or reverts each choice; then this record
  becomes `accepted`.

## Confirmed under delegation, 2026-10-09

- Context: on the evening of 2026-10-09 the maintainer went to bed and told
  the agent to continue with the next work and, for any decision that comes
  up, to "do it and report about it later". The handoff for this record asks
  for one question per item, which nobody could answer overnight. The agent
  checked each choice against the source, the tests, the cmdlet pages, and
  the changelog, and confirmed all ten. This is the agent's decision under
  that delegation, not the maintainer's own, so the status stays `proposed`
  until he confirms it or reverts an item. Nothing in the code, the tests,
  or the help changed.
- Impact for a caller, and where the choice is documented (the changelog
  under [Unreleased], and the page of each cmdlet in `Docs\Cmdlets`):

| # | Impact for a caller | Documented |
| --- | --- | --- |
| 1 | Without the Security privilege, `Get-NTFSOrphanedAudit` writes a non-terminating `ReadSecurityError` per item and goes on; an empty result no longer hides unread items. A script that took empty output for "nothing orphaned" now sees errors | `Get-NTFSOrphanedAudit` page, notes |
| 2 | A recursive `Get-NTFSSimpleAccess` reports the folders that earlier versions left out, with their subfolders; the output can have more rows | `Get-NTFSSimpleAccess` page, notes |
| 3 | None: `New-NTFSSymbolicLink` still needs the right to create symbolic links; Developer Mode doesn't help | `New-NTFSSymbolicLink` page, notes |
| 4 | With `-WhatIf`, a conflict at the destination is a verbose message, so `-WhatIf -ErrorAction Stop` no longer stops on it | `Move-Item2` page, description; the changelog |
| 5 | The warning of `Get-NTFSEffectiveAccess` names the computer; a script that matches the old text must change | the changelog |
| 6 | `Move-Item2` writes a `MoveError` for a folder on another volume and leaves the folder in place; before, AlphaFS copied and deleted it, which lost empty folders | `Move-Item2` page, notes; the changelog |
| 7 | **Breaking:** the link cmdlets write a non-terminating error per link and go on; a script that relies on the stop needs `-ErrorAction Stop` | both link pages, notes; the changelog, **Breaking** |
| 8 | **Breaking:** `-Path` and `-Target` are required; a script that omitted one must pass it | both link pages, notes; the changelog, **Breaking** |
| 9 | None: entries and descriptors are equal only as the same .NET object, as in .NET; `Compare-Object -Property` compares values | `Docs\FAQ.md` |
| 10 | Only against the earlier 5.0.0 prereleases: `Copy-Item2` no longer creates the missing folders of the destination of a folder copy, like `Copy-Item` and `Move-Item2` | `Copy-Item2` page; the changelog |

- Why all ten stand: 5.0.0 is a major version, so documented breaking
  changes are allowed (7 and 8 have a **Breaking:** entry and a migration
  hint); 1, 2, and 6 replace a result that looked valid with an error or a
  complete result; 3, 4, 9, and 10 follow the conventions of .NET and
  PowerShell and add no feature before the archive; 5 is a clearer message.
  Reverting item 8 would bring back the failure for every object piped to
  the link cmdlets (found on the way, above).
- To revert an item: revert its commit (the range in Context), regenerate
  the help from `Docs`, adjust the changelog and the cmdlet page, and run
  the four test configurations again; a later commit on the same page or
  test can conflict.
- Open: the maintainer confirms (`accepted`) or reverts each item.
