---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

PRs #94 (docs on GitHub) and #95 (manifest and version 5.0.0, stacked on
PR #94) are open and build on AppVeyor. The move to GitHub Actions (CI and
a wiki generated from `Docs`, Decision 11) is PR-ready on the local branch
`ai/github-actions`, stacked on #95; the maintainer pushes it and opens the
PR. Merge order: #94, #95 (merge commits), then the GitHub Actions PR.

## Evidence

- `Wiki.Tests.ps1` failed 25 of 25 before the exporter existed and passes
  25 of 25 in Windows PowerShell 5.1 and PowerShell 7.6.1. A negative
  control (broken anchor, missing page, missing file) reports all three.
- A dry run against a clone of the live wiki adds 41 pages, changes Home
  and How-to-install, and deletes the stale `Cmdlets.md` and
  `Version-History.textile`; nothing was pushed.
- `Invoke-Tests.ps1`, as CI calls it, passed locally against a Release
  build: Windows PowerShell 5.1 253 of 253; PowerShell 7 217 passed and 36
  skipped (`Get-Help -Online` runs only in Windows PowerShell).
- actionlint 1.7.12 reports nothing for `.github/workflows/ci.yml`. The
  runner image `windows-2025` has Visual Studio 2022 MSBuild 17.14, NuGet,
  the GitHub CLI, and PowerShell 7.6; `master` has no branch protection.
- The local branch `ai/read-the-docs` keeps the dropped strict-build work
  (`886c874`, `325ec76`); delete it once it is no longer wanted.

## Next step

After the maintainer pushes: read the AppVeyor results of #94 and #95 and
the first GitHub Actions run with `gh run view`. Work package 5 (code
defects) starts only after the maintainer's go-ahead.
