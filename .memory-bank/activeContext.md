---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Release 5.0.0 through CI, with the prerelease `5.0.0-rc1` first
(Decision 12). The release workflow, scripts, tests, and docs are PR-ready
on the local branch `ai/release-5.0.0`; the maintainer pushes it, opens the
PR, sets up the Gallery key and the environment `powershell-gallery`, and
tags `5.0.0-rc1` after the merge. Work package 5 (code defects) and the
open issues come after the release.

## Evidence

- Test first: `Tests\Release.Tests.ps1` failed 15 of 15 (Windows
  PowerShell: 9 failed, 6 skipped) before the scripts existed; the command
  tag test failed before the tags were added. Final: full suite 268 tests,
  PowerShell 7 232 passed and 36 skipped, Windows PowerShell 261 passed and
  7 skipped (packaging needs PowerShell 7).
- Package dry run: `NTFSSecurity.5.0.0-rc1.nupkg` (about 275 KB) with the 11
  `FileList` files, version `5.0.0-rc1`, release notes link, and 83 tags
  (36 `PSCmdlet_`, 36 `PSCommand_`, `PSIncludes_Cmdlet`); the extracted
  package imports in Windows PowerShell 5.1 and PowerShell 7.6.1 with 36
  cmdlets and working help. 4.2.6 on the Gallery has 37 + 37 command tags;
  PSResourceGet 1.2.0 `Compress-PSResource` adds none.
- actionlint, PSScriptAnalyzer, and markdownlint: no findings.
- `master` has 37 open issues; several overlap the work package 5 defects
  (for example #4) or are already fixed (#19 in 4.2.4; #15, #47, #66 by the
  documentation).
- The local branch `ai/read-the-docs` keeps the dropped strict-build work
  (`886c874`, `325ec76`); delete it once it is no longer wanted.

## Next step

After the maintainer opens the PR: read its CI run, and download the
`packages` artifact (`gh run download`) to compare it with the local dry
run. After the `5.0.0-rc1` tag: check the release job, the Gallery entry
(version, tags, `Find-Command Get-NTFSAccess`), and the GitHub prerelease.
