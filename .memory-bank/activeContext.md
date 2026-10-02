---
status: current
last-verified: 2026-10-02
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Work package 2 (ship the generated help) on branch `ai/ship-help`, stacked
on `ai/housekeeping`; the work packages and their order are in
`progress.md`.

## Evidence

- `Get-Help` showed only the syntax: the module shipped a pre-4.x MAML file
  named `NTFSSecurity-Help.xml`; PowerShell looks for
  `en-US\NTFSSecurity.dll-Help.xml` (`(Get-Command).HelpFile`).
- `New-ExternalHelp` output is byte-identical between runs (756,107 bytes,
  36 commands, UTF-8 with BOM, CRLF).
- `Tests\Help.Tests.ps1`: 218 of 218 pass in Windows PowerShell 5.1; 182
  pass and 36 skip in PowerShell 7.6.1. Without `bin\Release\en-US`, 180 of
  182 failed; against the baseline build, 144 of 146 failed; with the old
  help file, the link-spacing test failed for exactly the five reworded
  pages.
- PowerShell 7 resolves the same online URI (`GetUriForOnlineHelp` through
  the help system), but its `BypassOnlineHelpRetrieval` hook skips help
  files, so the `-Online` test is Windows PowerShell only.
- A parallel session committed `74abb0b` (PR #83 note) on `ai/ship-help`
  33 seconds after the branch was created and reset `ai/housekeeping` to
  it; `origin/ai/ship-help` exists at `74abb0b`.

## Next step

The maintainer pushes `ai/housekeeping` (`74abb0b`) and `ai/ship-help`,
opens the PR (base `ai/housekeeping` until WP1 merges), and confirms a
green AppVeyor run; then work package 3 (Read the Docs).
