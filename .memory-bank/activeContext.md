---
status: current
last-verified: 2026-10-04
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

5.0.0-rc1 is published (Gallery and GitHub prerelease, #98, tag
`5.0.0-rc1`) and verified. The maintainer tests it; after that comes the
final 5.0.0 release (remove the label, date the changelog, tag `5.0.0`),
then work package 5 (code defects) and the open issues. The local branch
`ai/memory-bank-rc1` holds this note and rides along with the next PR.

## Evidence

- Release run 37230802387: build, tests in both editions, packages,
  release checks, Gallery publish, and GitHub release all passed; the wiki
  job skipped the tag as designed.
- The Gallery nupkg (275,437 bytes) is byte-identical to the CI artifact,
  and the GitHub `NTFSSecurity.zip` to the CI zip; all 11 module files
  match. The DLLs are optimized Release builds (JIT optimizer enabled).
- Gallery: `IsPrerelease` true, `IsAbsoluteLatestVersion` true,
  `IsLatestVersion` false; stable `Find-PSResource` returns 4.2.6, with
  `-Prerelease` 5.0.0-rc1. 85 tags with all 36 `PSCmdlet_` and 36
  `PSCommand_`; the Gallery itself adds `PSEdition_Core` and
  `PSEdition_Desktop`.
- Installed with `Save-PSResource` and copied to `bin\Release`, the module
  passes the full suite: Windows PowerShell 261 passed, 7 skipped;
  PowerShell 7 232 passed, 36 skipped.
- The command search (`Find-PSResource -CommandName`) still returned 4.2.6
  at 20:16 UTC, four minutes after publishing; the search index was stale,
  because it treated 4.2.6 as the absolute latest version.
- The wiki was republished from `e0f5366`; Home mentions
  `-AllowPrerelease`.

## Next step

Recheck the command search for 5.0.0-rc1. When the maintainer reports test
results: prepare the final 5.0.0 release PR, or fix what the tests found
and publish `5.0.0-rc2`.
