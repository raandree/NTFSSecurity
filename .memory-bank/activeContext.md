---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

PRs #94, #95, and #96 are merged; CI and the wiki run on GitHub Actions.
The version history completed from the PowerShell Gallery packages is
PR-ready on the local branch `ai/version-history`; the maintainer pushes it
and opens the PR. Work package 5 (code defects) waits for the maintainer's
go-ahead.

## Evidence

- Six Gallery packages compared (4.0.0, 4.2.2 to 4.2.6), each imported in
  its own Windows PowerShell process: exported cmdlets 30, 35, 36, 36, 36,
  36. `Show-SimpleAccess` was exported only by 4.0.0 (the manifest of 4.2.2
  to 4.2.4 lists it as `Show-NTFSSimpleAccess`) and deleted in 4.2.5. All
  versions export the aliases `dir2`, `gi2`, `rm2`, and `del2` only.
- 4.2.4 already carried the MIT license (`LicenseUri`), the setting
  `IdentifyHardLinks`, and AlphaFS 2.2.1; 4.2.5 fixed the `-Account`
  aliases (#18, #36) and #48 but broke the `Applies to` column, which 4.2.6
  fixed (#57). 4.2.5 and 4.2.6 still ship AlphaFS 2.2.1: `d8f67af` updated
  only `packages.config`, not the `HintPath`.
- `Wiki.Tests.ps1` passes with the changed page; markdownlint (with `MD024`
  siblings only for `CHANGELOG.md`) and the link check found nothing.
- The local branch `ai/read-the-docs` keeps the dropped strict-build work
  (`886c874`, `325ec76`); delete it once it is no longer wanted.

## Next step

After the maintainer opens the PR: read its GitHub Actions run with
`gh pr checks`. Then wait for the go-ahead for work package 5.
