---
status: current
last-verified: 2026-10-02
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

PR #91 (`ai/docs-alignment`): CI fixed by building the module from source
in `appveyor.yml` and checking the docs against that build.

## Evidence

- AppVeyor build 54825990 failed in step 01: `Update-MarkdownHelp` against
  the Gallery module 4.2.6 rewrote `Remove-Item2 -PassThru` to `-PassThur`.
- Against a Release build of the source, `Update-MarkdownHelp` changes none
  of the 36 pages; a simulation of all `appveyor.yml` steps in a fresh clone
  passed, and a page with stale syntax made it fail as intended.
- The link check (`Get-MarkdownLink -BrokenOnly`) finds 308 links, none
  broken.
- Read the Docs project `ntfssecurity` still builds the fork
  `Sup3rlativ3/NTFSSecurity`.

## Next step

Push `ai/docs-alignment` (only on request) and confirm the AppVeyor build of
PR #91 passes on the Visual Studio 2022 image.
