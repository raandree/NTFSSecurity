---
status: accepted
date: 2026-10-02
last-verified: 2026-10-02
owner: shared
source: PR #91 (moved from systemPatterns.md)
---

# Decision 3: Document the source at HEAD

- Choice: Docs describe the code on `master`. Where HEAD differs from the
  latest Gallery release, the page says which version changed.
- Rationale: The user asked to align docs with the actual code; the only
  current difference is `Remove-Item2 -PassThru` (4.2.6 spells `-PassThur`).
