---
status: accepted
date: 2026-10-02
last-verified: 2026-10-02
owner: shared
source: PR #91 (moved from systemPatterns.md)
---

# Decision 4: Online help points to GitHub

- Choice: `online version` of every cmdlet page is
  `https://github.com/raandree/NTFSSecurity/blob/master/Docs/Cmdlets/<Name>.md`.
- Rationale: The Read the Docs project builds a stale fork, so its URLs show
  outdated pages; GitHub always shows `master`.
