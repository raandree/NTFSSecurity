---
status: accepted
date: 2026-10-02
last-verified: 2026-10-02
owner: shared
source: PR #91 (moved from systemPatterns.md)
---

# Decision 2: Cmdlet reference stays platyPS markdown

- Choice: `Docs/Cmdlets/*.md` keep the platyPS 0.14 schema 2.0.0 layout
  (upper-case section headings, YAML parameter blocks, one paragraph per
  line) so `Update-MarkdownHelp` and `New-ExternalHelp` round-trip.
- Rationale: `appveyor.yml` checks the pages with `Update-MarkdownHelp`;
  the same files can generate MAML help.
