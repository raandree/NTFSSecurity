---
status: proposed
date: 2026-10-08
last-verified: 2026-10-08
owner: shared
source: agent choices in autopilot on 2026-10-08, for the maintainer's review
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
