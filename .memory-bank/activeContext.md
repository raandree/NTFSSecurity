---
status: current
last-verified: 2026-10-02
owner: active-agent
source: current task evidence
---

# Active context

## Current focus

Documentation aligned with the cmdlets at HEAD (branch `ai/docs-alignment`).
Next candidates: ship generated MAML help, re-point the docs build, and fix
the code defects the documentation work surfaced.

## Evidence

- All 36 cmdlet pages filled from the C# source; 142 examples; no `{{`
  placeholders; examples checked against live parameter metadata.
- `Update-MarkdownHelp` against release 4.2.6 leaves 35 of 36 pages
  byte-identical; `Remove-Item2` differs only by `-PassThru` (HEAD) versus
  `-PassThur` (4.2.6).
- `New-ExternalHelp` builds `NTFSSecurity.dll-Help.xml` (36 commands);
  `Get-Help` renders it when placed in `en-US` of a module copy.
- Read the Docs project `ntfssecurity` and the AppVeyor project build the
  fork `Sup3rlativ3/NTFSSecurity`; the last RTD build is about 5.75 years old.

## Next step

Await the next task. Open follow-ups are listed in `progress.md`.
